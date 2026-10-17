// 截开发环境页面的电脑版和手机版各一张，用来检查界面和主题是否融合。
// 在容器里运行（开发服务器要先启动）：
//   docker cp script/screenshot.mjs discourse_dev:/tmp/screenshot.mjs
//   docker exec -u discourse -e HOME=/home/discourse discourse_dev node /tmp/screenshot.mjs /t/some-topic/123 /tmp/shot [用户名 密码]
//   docker cp discourse_dev:/tmp/shot-desktop.png . （手机版是 shot-mobile.png）
// 给了用户名和密码就先登录。只用于本地开发库里的测试账号。
import { chromium, devices } from "/src/node_modules/playwright/index.mjs";

const [path = "/", prefix = "/tmp/shot", username, password] = process.argv.slice(2);
const base = "http://localhost:3000";
const xhr = { "X-Requested-With": "XMLHttpRequest" };

async function logIn(context) {
  const { csrf } = await (await context.request.get(`${base}/session/csrf`, { headers: xhr })).json();
  const response = await context.request.post(`${base}/session.json`, {
    headers: { ...xhr, "X-CSRF-Token": csrf },
    form: { login: username, password },
  });
  if ((await response.json()).error) {
    throw new Error(`login failed for ${username}`);
  }
}

async function capture(context, file) {
  if (username) {
    await logIn(context);
  }

  const page = await context.newPage();
  // MessageBus 一直保持长连接，等不到 networkidle
  await page.goto(base + path, { waitUntil: "load", timeout: 120000 });
  await page.waitForSelector("#main-outlet", { timeout: 120000 });
  await page.waitForTimeout(1500);
  await page.screenshot({ path: file });
}

// 容器里只装了完整版 Chromium（pnpm playwright-install 用 --no-shell）
const browser = await chromium.launch({ channel: "chromium" });
try {
  await capture(
    await browser.newContext({ viewport: { width: 1366, height: 900 } }),
    `${prefix}-desktop.png`
  );
  // 手机 User-Agent，Discourse 才会给手机版布局
  await capture(await browser.newContext({ ...devices["iPhone 13"] }), `${prefix}-mobile.png`);
} finally {
  await browser.close();
}
