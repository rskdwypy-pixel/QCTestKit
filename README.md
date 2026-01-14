# QCTestKit

QCTestKit 是一款 iOS 自动化测试工具 APP，提供浏览器调试、网络测试和崩溃测试等功能。

## 功能特性

### 🌐 浏览器模块
- 基于 WKWebView 的网页浏览器
- 实时加载进度显示（百分比 + 状态）
- 智能缓存检测（自动识别从缓存加载的页面）
- 加载状态诊断（成功/失败记录）
- 诊断历史记录查看
- 网络请求日志分析

### 📡 网络测试模块
- 全面的 HTTP 状态码测试场景
  - 2xx: 200, 201, 204
  - 3xx: 301, 302, 304, 307, 308
  - 4xx: 400, 401, 403, 404, 429
  - 5xx: 500, 502, 503, 504
- 弱网场景模拟（2G/3G/高延迟/电梯）
- 自定义测试场景
- DNS 失败、SSL 错误、超时测试

### ⚡ 崩溃测试模块
- 基础崩溃模拟
  - 应用闪退
  - NSException 异常
  - 未捕获异常
- 性能问题模拟
  - UI 卡顿
  - 主线程阻塞
  - 内存泄漏
- 崩溃日志收集与恢复机制

### ⚙️ 设置模块
- 应用配置管理
- 关于页面

## 技术栈

- **开发语言**: Objective-C
- **架构**: MVC + 模块化
- **主要框架**:
  - UIKit
  - WebKit
  - Foundation
  - Network
  - CFNetwork

## 系统要求

- iOS 13.0+
- Xcode 12.0+

## 安装

```bash
git clone https://github.com/rskdwypy-pixel/QCTestKit.git
cd QCTestKit
open QCTestKit.xcodeproj
```

## 项目结构

```
QCTestKit/
├── Application/                # 应用入口
├── Common/                     # 公共模块
│   ├── Base/                   # 基类
│   ├── Categories/             # 分类扩展
│   ├── Utils/                  # 工具类
│   └── Constants/              # 常量定义
├── Main/                       # TabBar 容器
├── BrowserModule/              # 浏览器模块
├── NetworkModule/              # 网络测试模块
└── CrashModule/                # 崩溃测试模块
```

## 使用说明

### 浏览器模块
1. 在地址栏输入 URL 或选择预设网址
2. 点击「前往」按钮加载网页
3. 查看实时加载进度和状态
4. 加载完成后可查看详细诊断信息
5. 在诊断历史中查看过往记录

### 网络测试模块
1. 选择预设场景或配置自定义场景
2. 点击「执行测试」
3. 查看测试结果和详细日志

### 崩溃测试模块
1. 选择要测试的崩溃类型
2. 点击执行（注意：某些测试会导致应用闪退）
3. 重启应用后查看崩溃日志

## 开发说明

### Info.plist 配置

项目已配置以下权限：

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

MIT License

## 作者

Created with Claude Code
