# 《这货谁送的？》Agent 协作规范

Agent 的 D/E 身份只由 B 在当前任务中明确指派。D 使用 DSH，E 使用 Codex。

## 阅读顺序

1. 先读 B 的当前派发任务和本规范，核对本次授权范围与共同基线。[B 统筹总表](docs/交接/B_策划_API与协调.md)
2. 玩法和参数状态查灰盒。接口语义查 API，实现时复用同版 C# 声明。发现不一致时记录给 B，并继续可独立推进的部分。[灰盒 v0.5](docs/灰盒设计_v0.1.md) · [API v0.6](docs/API与联调契约_v0.2.md) · [共享契约](who-sent-this-guy/shared/contracts/)
3. 按本方交接单实施，查对方交接单确认接点，按清单提交阶段证据。[D 交接单](docs/交接/D_独立功能实现.md) · [E 交接单](docs/交接/E_独立功能实现.md) · [D/E 验收清单](docs/交接/DE_开发与验收清单.md)

## B｜策划、协调与验收

B 负责确认玩法、经济参数、API 语义和联机方案，指定基线与阶段范围，汇总 D/E 互审并验收。接口的新增、改签名或改语义由 B 确认，E 统一接入共享声明。

## D｜DSH，玩家侧

- 在 D 的独立工作树中使用 `who-sent-this-guy/` 作为工程目录。负责工程内的 `features/player_operations/` 与 `tests/player_operations/`。独立入口为 `who-sent-this-guy/tests/player_operations/player_operations_test.tscn`。
- 实现人物、镜头、手册和绑定、玩家输入与交互、HUD、房间界面和本地反馈。向 E 提交意图，用确认结果和快照更新表现。可用占位资源与可替换模拟服务。
- 禁止代改 E 的权威服务、运输功能包、共享类型、正式主场景和工程级设置。

## E｜Codex，权威业务与工程接入

- 在 E 的独立工作树中使用 `who-sent-this-guy/` 作为工程目录。负责工程内的 `features/cargo_transport/`、`features/delivery_flow/`、`features/economy/`、`features/incidents/` 与 `tests/cargo_transport/`。独立入口为 `who-sent-this-guy/tests/cargo_transport/transport_test.tscn`。
- 实现车货物理、凝胶、路线订单、加油、事件及恢复，负责世界音频、正式会话、房主裁决、同步和断线处理。可用占位资源、模拟玩家和临时操作测试本地权威服务。E 统一接入共享声明、工程级设置和正式主场景，目标入口为 `who-sent-this-guy/scenes/graybox_delivery.tscn`。
- 通过共同接口接入 D 的人物与玩家侧模块。禁止代改 D 的输入、镜头、界面、玩家功能包和独立测试场。

## 接口与范围

- D 提供人物、镜头、手册和绑定服务，E 提供会话和权威业务服务。双方用 `DeliveryGame.Contracts` 的同一版本定义请求、快照和事件，按已确认版本消费结果。
- 共同接口的变更先向 B 提出受影响的调用方、字段和兼容性。B 确认后由 E 接入，D 按同版接口复验。涉及跨模块改动或调整灰盒和 API 时先交 B 协调。未确认的玩法、经济和协议问题登记为「待 B 确认」，测试配置注明来源和实际值。
- A/C 已派发的任务文档禁止修改。首次真实联调接凝胶回收，从 D 的操作到 E 的物理及库存提交，再到 D 的 HUD 刷新。单机装运卸闭环通过后接正式联机。[API 第 11 节](docs/API与联调契约_v0.2.md#11-de-并行开发约定)

## Git 与验证

- D/E 从 B 指定的同一个 `origin/main` 完整 SHA 创建各自分支并记录。只暂存本次任务文件，执行 `git diff --cached --check` 并核对清单后提交。开发、提交和推送均在本方分支，PR 交给对方互审和 B 审查合入。
- PR 写明共同基线 SHA、任务编号、改动范围、运行与 CI 证据、已知问题和未执行项。遇冲突先保全工作区和暂存改动，本方范围内解决并复测，涉及共享或对方文件交 B 协调。
- 禁止覆盖或批量清理现有工作，禁止 `git reset --hard`、`git clean -fd` 和强制推送。
- 先编译，再实际启动本方 Godot 场景，执行适用的自动化构建与回归。记录命令、退出码、日志及 CI 链接。按清单提交模拟、真实服务和正式联机各自的运行证据。
- 失败时记录场景、提交、配置、人数、最小复现、预期与实际结果和影响。核心案例失败记为阻断，尚未运行的检查留在未执行项。首轮派发验收到 P1，后续按清单完成。
