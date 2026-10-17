# discourse-kuu-ratings（给 Claude Code）

## 这是什么
- 京大中文论坛（KUU，Discourse 自托管）的评分插件，用来吸引第一批用户
- 技术方案（数据设计、页面、接口、分期计划）：Notion「项目中心 › 项目文档 › 京大论坛｜评分插件技术方案」
  https://app.notion.com/p/3fc43ea2113c8143b9b3eec0d2d8ad06 。开发前先读这份方案；方案改了要同步更新 Notion
- 论坛的运维记录、待办、上线记录在另一个私有仓库：Windows 上的 `D:\PROJECT\KUU`（GitHub `kuu-forum`）。插件上线、线上改配置这些事要记在那边的 CHANGELOG 里
- 本仓库是**公开**的：不要提交任何密钥、服务器地址以外的敏感信息、用户数据

## 已确定的规则（不要自行改）
- 一个评分主题里有多个评分对象；评分主题和评分对象都是 topic，分别在「评分」「评分 › 评分对象」分类，靠分类的「新话题需审核」进审核队列
- 10 分制，像虎扑一样显示五颗星，每颗星 2 分，只能选整颗星：每人对每个评分对象打一次分（2/4/6/8/10），数据库存 10 分制的分数，平均分可以是小数；短评选填；不能修改，只能删除后重打（删除时短评一起删）
- 短评不经过审核，也不走 core 的回帖长度检查（插件自己限制 1–500 字），但 core 的其他发帖限制照常
- 评分对象帖子里直接回复对象的都是短评，必须打分；短评可以被回复，回复不用打分
- 打分不匿名：不写短评的打分也能看到是谁打的；用户在评分对象下的任何发言旁边都显示这个用户的分数
- 不管从哪里删掉短评，对应的打分都一起删
- 评分主题关闭或删除后，里面的对象不能再打分；发起人可以给自己添加的对象打分
- 评分对象必须有：名称（topic 标题）、图片（正文第一张图）、一句话简介（topic custom field）
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
- lint 要在容器里跑：`d/exec bin/lint --fix <文件...>`，路径相对 `~/discourse`
- `d/` 脚本都用 `docker exec -it`。没有终端时（比如后台运行）会报 `the input device is not a TTY`，要用 `script -qec '命令' /dev/null` 包一层
- 插件的启用开关是站点设置 `kuu_ratings_enabled`，默认关闭，开发环境要在后台打开

## 约定
- Ruby 模块 `DiscourseKuuRatings`，接口挂在 `/kuu-ratings`
- 代码标识符用英文；面向用户的文案放在 `config/locales/`（zh_CN 和 en 都要有）
- 跟着 Discourse 官方插件的写法走：前端用 Glimmer 组件（.gjs）和 plugin outlet，不要改 core
- 每个功能都要写测试（RSpec；前端交互用 system spec）
- 提交信息用中文；推送到 GitHub 之前先跑测试
- 部署到线上（改服务器 app.yml、rebuild）必须先得到 David 的同意，在 KUU 仓库那边操作和记录
- 用中文交流
