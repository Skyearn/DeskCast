## 更新内容

- 修复 Mac 睡眠或唤醒后，多显示器投影位置会被错误改写的问题。
- 目标显示器在唤醒阶段短暂不可用时，投影会临时回退显示，但不会再把原屏幕保存的位置永久改成回退后的值。
- 优化屏幕配置变化时的状态同步逻辑，让显示器恢复后更稳定地回到原来的屏幕和布局。

<details>
<summary id="english">English release notes</summary>

- Fixed an issue where projection positions could be incorrectly rewritten after Mac sleep and wake in multi-display setups.
- When the target display becomes briefly unavailable during wake, the projection may temporarily fall back, but the original saved position will no longer be permanently overwritten by the fallback value.
- Improved screen-configuration synchronization so projections return more reliably to their original display and layout after the screen comes back.

</details>
