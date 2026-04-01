## 更新内容

- 优化菜单栏投影面板和整体编辑体验。
- 修复目标显示器断开时的多屏回退逻辑。
- 投影在目标显示器断开后会临时回退到主屏，并在原显示器恢复连接后自动回到原屏。
- 修复回退期间原屏幕名称显示不稳定的问题，更可靠地保留原显示器名称。
- 修复回退期间修改位置和大小会影响原屏恢复布局的问题。
- 补充 README 演示资源与自动构建、自动发布流程。

<details>
<summary id="english">English release notes</summary>

- Improved the menu bar projection panel and overall editing experience.
- Fixed multi-display fallback behavior when a target screen disconnects.
- Projections now temporarily fall back to the primary display and automatically restore when the original display reconnects.
- Fixed screen-name persistence so the original display name is preserved more reliably during fallback.
- Changes made while in fallback mode no longer overwrite the original screen layout.
- Added README demo assets and release/build automation for publishing.

</details>
