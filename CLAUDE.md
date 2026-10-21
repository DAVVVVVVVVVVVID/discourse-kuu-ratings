# discourse-kuu-ratings（给 Claude Code）

## 这是什么
- 京大中文论坛（KUU，Discourse 自托管）的评分插件，用来吸引第一批用户
- 技术方案（数据设计、页面、接口、分期计划）：Notion「项目中心 › 项目文档 › 京大论坛｜评分插件技术方案」
  https://app.notion.com/p/3fc43ea2113c8143b9b3eec0d2d8ad06 。开发前先读这份方案；方案改了要同步更新 Notion
- 论坛的运维记录、待办、上线记录在另一个私有仓库：Windows 上的 `D:\PROJECT\KUU`（GitHub `kuu-forum`）。插件上线、线上改配置这些事要记在那边的 CHANGELOG 里
- 本仓库是**公开**的：不要提交任何密钥、服务器地址以外的敏感信息、用户数据

## 已确定的规则（不要自行改）
- 一个评分主题里有多个评分对象；评分主题和评分对象都是 topic，分别在「评分」「评分 › 评分对象」分类
- 新建评分主题和添加评分对象都用插件自己的表单，不用 Discourse 的发帖框：评分主题只有名称，创建时至少带 2 个评分对象；评分对象只有图片和名称。名称都是 30 字以内，同一个评分主题里对象不能重名
- 「新建话题」按钮统一由 `discourse-kuu-new-topic` 插件处理（2026-10-18 定）。本插件不再注册 `create-topic-button-click`、`can-create-topic-button` 转换器，只向它登记「评分主题」类型（`id: kuu-ratings-board`）：评分分类里直接打开表单，其他地方出现在选择框里。新插件是硬依赖：CI 通过 `about.json` 一起安装，线上要和本插件一起装；本地在 `~/discourse/plugins/discourse-kuu-new-topic`，不要改它，接口不够用先告诉 David
- 审核用插件自己注册的审核类型：新建评分主题时「主题 + 所有对象」打包成一条，作为整体批准或拒绝；单独添加的对象一个一条。批准后插件才建帖子，首帖内容由插件生成；插件建帖时跳过 Discourse 的标题最短长度和不能重名两条规则
- 评分主题页不显示首帖，标题下面直接是评分对象横条列表（左图片，名称和第一条热评，右边星星、分数保留 1 位小数、打分人数）
- 10 分制，像虎扑一样显示五颗星，每颗星 2 分，只能选整颗星：每人对每个评分对象打一次分（2/4/6/8/10），数据库存 10 分制的分数，平均分可以是小数；**短评必填**（2026-10-21 定，Issue #7：2–500 字；以前只打星的打分由 `rake kuu_ratings:backfill_star_reviews` 补一条「N星」短评）；不能修改，只能删除后重打（删除时短评一起删）
- 短评不经过审核，也不走 core 的回帖长度检查（插件自己限制 2–500 字），但 core 的其他发帖限制照常
- 评分对象帖子里直接回复对象的都是短评，必须打分；短评可以被回复，回复不用打分
- 打分不匿名：不写短评的打分也能看到是谁打的；用户在评分对象下的任何发言旁边都显示这个用户的分数
- 不管从哪里删掉短评，对应的打分都一起删
- 评分主题关闭或删除后，里面的对象不能再打分；发起人可以给自己添加的对象打分
- 所有注册用户都能发起和添加；打分人数不设门槛
- 不评具体的人、课程、研究室

## 开发环境
- 本仓库位于 WSL 的 `~/discourse/plugins/discourse-kuu-ratings`，Discourse 源码在 `~/discourse`（官方仓库，不要改）
- 在 `~/discourse` 下执行：
  - `d/boot_dev`：启动容器；`d/shutdown_dev`：停止容器（不开发时停掉，本机内存只有 7.8GB）
  - `d/dev`：启动开发服务器，打开 http://localhost:3000
  - `d/rspec plugins/discourse-kuu-ratings/spec`：跑本插件的测试
  - `d/rake db:migrate`，再执行 `RAILS_ENV=test d/rake db:migrate`：加了数据库迁移之后两个库都要跑
  - 测试库回滚插件迁移时要带上插件：`RAILS_ENV=test d/exec env LOAD_PLUGINS=1 bin/rake db:migrate:down VERSION=...`（`d/` 脚本只转发 `RAILS_ENV` 等少数环境变量，不转发 `LOAD_PLUGINS`）
- 浏览器测试（spec/system）要求容器里有 Playwright 浏览器和它依赖的系统库。容器新建或 Playwright 升级后，报 `Executable doesn't exist` 或 `error while loading shared libraries` 时执行：
  - `d/exec pnpm playwright-install`（下载浏览器）
  - `docker exec -u root -w /src discourse_dev bash -c 'pnpm exec playwright install-deps chromium'`（用 root 装系统库）
- 停掉 `d/dev`（或它崩溃）之后，`~/discourse/frontend/discourse/dist/manifest/build.json` 还记着已经不存在的 rolldown 进程，system spec 会报 `Rolldown process (pid ...) is no longer running`，一片失败。删掉这个文件再跑；`d/dev` 启动时报 `rolldown devserver is already running` 也是同一个原因
- 开发服务器和全部测试同时跑时 WSL 内存不够（共 4.9GB），会出现和代码无关的随机失败。跑全部测试前先停掉 `d/dev`
- 其他 KUU 插件（二手、京大邮箱等）的 Claude Code 会话共用同一个 `discourse_dev` 容器，它们也会开 `d/dev`、跑截图和测试。全部测试大面积报 `NoSuchWindowError`（测试用的浏览器崩了）时，先 `docker exec discourse_dev ps -eo pid,rss,etime,args --sort=-rss | head` 看看是不是别的会话占着内存；不要结束别的会话的进程，等它们跑完再重跑失败的文件
- 测试环境的样式表只在第一次跑 system spec 时算一次版本号，之后改了 SCSS 也不会重新编译（现象：system spec 里插件样式是旧的或缺失，比如首帖没隐藏）。改完样式要删掉缓存：`rm -f ~/discourse/tmp/cache/assets/test/stylesheet-manifest-test_* && rm -rf ~/discourse/tmp/stylesheet-cache/test_*`
- 改了 `plugin.rb` 之后，开发服务器会自动重载，但可能留下一个孤儿 worker（`ps -eo pid,ppid,args` 里 PPID 为 1 的 `pitchfork ... worker`），它继续用旧代码接请求，现象是页面时好时坏（比如插件样式时有时无）。`docker exec discourse_dev kill <pid>` 结束它，或者重启 `d/dev`
- 开发服务器重载代码（比如改了 `lib/` 下的文件）之后，插件在 `after_initialize` 里注册到 core 的东西可能从 web 进程里丢失，但 `rails runner` 里一切正常。见过的现象：审核队列看不到「评分投稿」、按类型筛选报 400 `invalid_parameters: type`；「最新」里又出现评分对象（`TopicQuery.add_custom_filter` 丢了）。重启 `d/dev` 就好，线上不受影响
- 截图脚本登录用的测试账号要先在本地开发库里建好（用户名、密码自己定，不要用真实账号）
- lint 要在容器里跑：`d/exec bin/lint --fix <文件...>`，路径相对 `~/discourse`
- `d/` 脚本都用 `docker exec -it`。没有终端时（比如后台运行）会报 `the input device is not a TTY`，要用 `script -qec '命令' /dev/null` 包一层
- 插件的启用开关是站点设置 `kuu_ratings_enabled`，默认关闭，开发环境要在后台打开
- 本地开发库装了和线上同一版本的 FKB Pro（GitHub `VaperinaDEV/fkb-pro-theme` 提交 `bc006ce132`，配色 FKB Pro - Light，设为默认，主题设置都是默认值）。因为后台「从 GitHub 安装」只能装最新版，是 checkout 到这个提交后用 `RemoteTheme.import_theme_from_directory` 导入的。恢复原样：本地后台把 Foundation 设为默认
- 截图检查界面：`script/screenshot.mjs`（用法见文件开头），电脑和手机宽度各一张

## 界面风格（2026-10-17 定）
- 要和线上的 FKB Pro 主题融洽：白底卡片、浅阴影、圆角，主色是蓝色（`--tertiary`）
- 插件只用 Discourse 自带的 CSS 变量（`--primary`、`--secondary`、`--tertiary`、`--d-default-border-radius` 等）和 ui-kit 组件，不写死颜色；这样主题换配色、开深色模式时会自动跟着变
- 星星用金黄色，定义成可覆盖的变量 `--kuu-star-color`
- 只对 FKB Pro 有效的微调不写进插件，放进 KUU 仓库的「KUU 自定义组件」（`theme/` 目录）
- 每做完一个页面，截电脑和手机宽度的图给 David 确认后再做下一个

## 约定
- Ruby 模块 `DiscourseKuuRatings`，接口挂在 `/kuu-ratings`
- 代码标识符用英文；面向用户的文案放在 `config/locales/`（zh_CN 和 en 都要有）
- 跟着 Discourse 官方插件的写法走：前端用 Glimmer 组件（.gjs）和 plugin outlet，不要改 core
- 每个功能都要写测试（RSpec；前端交互用 system spec）
- 提交信息用中文；推送到 GitHub 之前先跑测试
- 部署到线上（改服务器 app.yml、rebuild）必须先得到 David 的同意，在 KUU 仓库那边操作和记录
- 用中文交流
