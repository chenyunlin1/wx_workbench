# 鸿蒙应用模板

这是一个 HarmonyOS 应用模板：预置沉浸式布局、底部标签导航与设置框架，复制后可直接用于开发新应用。

## 模板内容

- **底部四页签**（HdsTabs）：音乐 / 书架 / 视频 为空白占位页，开发时替换为真实功能；「我的」为完整功能页
- **我的**：设置、关于、图标主题
- **设置**：外观（主题模式 / 材质效果 / 主题色）与启动（默认打开的页签）
- **关于**：使用说明、开源声明、合规说明、隐私政策四个子页面（均为模板占位文案，发布前替换）
- **图标主题**：基于系统 `alternateIcons` 的桌面图标切换（API 26+），预置 12 套图标
- **深浅色双资源**（`base` / `dark` 双份 `element/color.json`），主题色即时切换
- **自适应布局**：手机 / 平板 / 2in1，窗口尺寸变化不丢失布局

## 技术栈

- ArkTS 严格模式 + ArkUI **V2**（`@ComponentV2` / `@Local` / `@Param` / `@Event` / `@ObservedV2` / `@Trace`）
- 最低 HarmonyOS 6.0（API 20），`targetSdkVersion 26.0.0`
- `@kit.UIDesignKit` HdsTabs：API 23+ 悬浮页签栏、API 26+ 沉浸光感材质，低版本自动降级（见 `utils/PlatformCompat.ets`）

## 快速开始

1. 用 DevEco Studio（Release SDK）打开工程
2. 在 File > Project Structure > Signing Configs 中配置本机签名（`build-profile.json5` 中的签名配置与设备绑定，不要提交）
3. 修改应用身份：`AppScope/app.json5` 的 `bundleName` / `versionName`，`AppScope/resources/base/element/string.json` 的 `app_name`
4. 替换业务：把 `MainPage` 中前三个占位页签换成真实页面，文案统一写在 `entry/src/main/resources/base/element/string.json`
5. 构建运行：

   ```
   ohpm install
   hvigorw assembleHap --mode module -p product=default
   ```

   或直接使用 DevEco Studio 的运行按钮（需先成功构建）

## 目录结构

```
AppScope/                          应用级配置与图标资源（含 alternateIcons 声明）
entry/src/main/
  ets/
    entryability/                  EntryAbility 入口（沉浸式窗口、偏好初始化）
    pages/                         Index 路由表、MainPage 四页签、ProfilePage、
                                   SettingsPage、AppIconPage、AboutPage、
                                   GuidePage、PrivacyPage、CompliancePage、OpenSourcePage
    components/                    外观设置、沉浸按钮/选项、占位页、菜单转场
    service/                       PreferenceService（偏好持久化）、
                                   AppIconService（图标切换）、UpdateService（版本信息）
    model/                         AppAppearance（V2 响应式外观状态）
    theme/                         Theme.ets 设计 token（颜色/材质/间距/圆角/字号/动效）
    utils/                         WindowUtils（窗口与安全区）、PlatformCompat（版本兼容）、
                                   AdaptiveLayout（自适应）、HdsCompat（UIDesignKit 降级）
  resources/
    base|dark/element/             字符串与颜色资源（深浅双份，键集合保持一致）
    base/media/                    图标主题图片资源
    base/profile/main_pages.json   页面清单
```

## 开发约定

- 只使用 ArkUI V2 装饰器，禁止混用 V1（`@Component` / `@State` / `@Prop` / `@Link` / `@Watch` 等）
- 界面文案一律写入 `string.json`，代码中不写中文字面量
- 颜色走 `theme/Theme.ets` 的 token 或系统 `sys.color.*`，不写裸色值
- 列表使用 `LazyForEach` + 稳定键，禁止用下标作为键
- 新增 API 时用 `PlatformCompat.supports(apiVersion)` 判断并提供降级路径
- 标签栏顺序为 音乐 / 书架 / 视频 / 我的；调整页签时同步更新 `SettingsPage` 的「默认打开」选项

## 注意事项

- `build-profile.json5` 含本机签名机密，若纳入版本管理请改提交 `build-profile.template.json5`
- 桌面图标切换与沉浸材质需要 API 26+；悬浮页签栏需要 API 23+，低版本自动降级
- 工程无构建 CI，请以 DevEco Studio / hvigor 本地构建结果为准
