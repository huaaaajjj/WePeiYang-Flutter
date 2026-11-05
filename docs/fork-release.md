# 平板版发行约定

本 fork 的更新检查使用 GitHub 正式 Releases，不跟踪分支提交或预发布；无需维护另一份更新服务器清单。

## 版本与附件

- 标签使用 `vX.Y.Z-pad.N`，例如 `v4.6.4-pad.3`。
- `pubspec.yaml` 的版本为 `X.Y.Z+buildNumber`；build number 必须递增，并与 `EnvConfig.VERSIONCODE` 一致。
- APK 必须按标签源码构建，不另用 `VERSION`、`VERSIONCODE`、`--build-name`、`--build-number` 覆盖版本。
- 通用 ARM APK 命名为 `WePeiYang-For-Pad-<标签>-release.apk`。每个 Release 只上传一个同名 APK，须为 uploaded 状态且有 GitHub 提供的 SHA-256 digest。
- Release 必须非 draft、非 prerelease，发布完成后设为 Latest。
- 独立包名保持 `com.twt.service.pad`；后续覆盖升级必须保留同一签名。当前仍沿用测试签名，不代表官方发行签名。

客户端从正式 Release 读取附件信息，从同一标签的 `pubspec.yaml` 读取 build number，再与实际安装版本比较。下载完成、缓存命中、安装前均验证字节数与 SHA-256；Android 安装桥接还会检查包名、签名和 APK 内部版本号。

## 构建与验证

本次环境为 Flutter 3.47.7 / Dart 3.13.5。配置本机 Android SDK 和 `android/local.properties` 中的签名信息；不要提交密钥或密码。

```sh
flutter pub get
flutter test --no-pub
flutter analyze --no-pub
flutter build apk --release --target-platform=android-arm,android-arm64 --dart-define=ENVIRONMENT=RELEASE
```

产物为 `build/app/outputs/flutter-apk/app-release.apk`。按上述约定改名，核对 APK 版本、签名、SHA-256，再上传 APK 与校验文件。现有 27 warning、2 info 会让 analyze 返回非零状态；不能据此忽略新增诊断。

Windows 项目和 Pub 缓存跨磁盘时，若遇 Kotlin `different roots` / `Storage ... already registered`，可仅为当前构建设置 `GRADLE_OPTS=-Dorg.gradle.project.kotlin.incremental=false -Dorg.gradle.project.kotlin.compiler.execution.strategy=in-process`，不要为此删除签名或全局缓存。

## 用户升级

旧 `pad.2` 没有自动检查能力，需要手动下载安装 `pad.3` 一次；之后启动应用发现更高版本的正式 Release 会提示更新。下载安装仍需用户确认，未知来源安装权限由 Android 管理，不静默安装。单纯推送代码不会触发应用更新。

网络超时或 GitHub 限流时，自动检查不打扰用户，手动检查显示失败；下载或校验失败可重试，网页兜底仅指向本 fork。原包及 `.develop` 不改变其原有更新源。
