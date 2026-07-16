# Agents 文档索引（`.agent/`）

本目录存放给 **AI Agent / 跨 Session 接手** 用的项目说明。人类开发者也可用，但以「快速建立上下文、少踩坑」为目标。

仓库根目录的 [`AGENTS.md`](../AGENTS.md) 指向此处。

| 文档 | 用途 |
|------|------|
| [PROJECT.md](./PROJECT.md) | **主文档**：产品目标、架构、目录、数据流、关键约定、已知坑、验证方式 |
| [CHANGELOG-AGENT.md](./CHANGELOG-AGENT.md) | Session 级变更摘要（接手时先扫一眼最近改了什么） |

## 接手最短路径

1. 读完 `PROJECT.md`（约 5–10 分钟）
2. 扫 `CHANGELOG-AGENT.md` 最近条目
3. `git status` / `git log -5` 确认本地与文档是否一致
4. 用 Xcode 或 `xcodebuild` 能编过再动代码

## 写回约定

完成一轮有意义的开发后，请 **更新** `CHANGELOG-AGENT.md`（追加一条），必要时同步改 `PROJECT.md` 中已过时的描述（架构、坑、范围）。
