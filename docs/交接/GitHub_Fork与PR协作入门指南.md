# GitHub Fork 与 PR 协作入门指南

D 用 DSH 开发玩家侧，E 用 Codex 开发运输、物理和权威服务。两人各自提交 PR，由项目仓库拥有者 B 审查和合并。

## 先认识六个词

- **Fork** 是在自己的 GitHub 账号下创建原仓库的副本。例如，你可以在自己的 GitHub 主页找到一份 `你的GitHub用户名/GGGGGame`。
- **Clone** 是把 GitHub 仓库下载到电脑。例如，Clone 自己的 Fork 后，电脑上会出现一个 `GGGGGame` 目录。
- **Branch（分支）** 是在同一个仓库里单独开发的一条线。例如，D 可以在玩家侧分支上做改动。
- **Commit（提交）** 是在本地保存一组已选定的修改，并给这次记录写一句说明。
- **Push（推送）** 是把本地的 Commit 上传到 GitHub。例如，推送后可以在自己的 Fork 上看到最新提交。
- **Pull Request（PR）** 是把自己的分支交给 B 审查，并请求将改动合并进原仓库。

Fork 会在 GitHub 上新建一个仓库。复制本地文件夹只是在电脑上复制文件，创建 Branch 则是在现有仓库里开一条开发线。

## 1. 在 GitHub 上 Fork 项目

1. 打开 GitHub，登录你自己的账号。
2. 打开 B 的原仓库。[bydgs5418823/GGGGGame](https://github.com/bydgs5418823/GGGGGame)
3. 点击仓库页右上角的 **Fork**。
4. 在 **Owner** 下拉框选你自己的账号，仓库名保留为 `GGGGGame`。
5. 点击 **Create fork**。
6. 查看新页面顶部。仓库全名应为 `你的GitHub用户名/GGGGGame`，并标明 Fork 自 `bydgs5418823/GGGGGame`。

B 的原仓库是项目的上游，你名下的 Fork 是用来接收自己推送的仓库。[GitHub 的 Fork 操作说明](https://docs.github.com/zh/pull-requests/how-tos/work-with-forks/fork-a-repo)

## 2. 用 PowerShell 克隆自己的 Fork

在任意目录开一个 Windows PowerShell，运行 `git --version`。显示 2.23 或更新版本即可继续。找不到命令或版本更早时，安装或更新 Git for Windows，再重新打开 PowerShell。[GitHub 的 Git 设置指南](https://docs.github.com/zh/get-started/git-basics/set-up-git)

在**自己的 Fork** 页面点 **Code → HTTPS**，核对地址中仓库名前面是你自己的 GitHub 用户名。把下面的目录换成电脑上已存在、且还没有 `GGGGGame` 子目录的位置。把 `你的GitHub用户名` 换成自己的用户名，使用你的 GitHub 个人主页地址中的名字。逐行执行命令，遇到报错先停下。

```powershell
Set-Location -LiteralPath 'D:\你的开发目录'
$GitHubUser = '你的GitHub用户名'
git clone "https://github.com/$GitHubUser/GGGGGame.git"
Set-Location -LiteralPath 'GGGGGame'
git remote -v
```

前两行选定存放位置和账号，`git clone` 下载仓库并建立 `GGGGGame` 目录。进入该目录后，`git remote -v` 会列出远程地址。确认 `origin` 的 `fetch` 和 `push` 地址都包含**你自己的用户名**。如果显示的是 B 或其他人的账号，先保留当前目录，再用自己 Fork 的地址克隆到新位置。

仍在这个克隆目录中，添加指向 B 原仓库的 `upstream`。这条添加命令只需运行一次。

```powershell
git remote add upstream https://github.com/bydgs5418823/GGGGGame.git
git remote -v
```

看到 `origin` 指向自己的 Fork，`upstream` 指向 `bydgs5418823/GGGGGame` 就配好了。后面从 `upstream` 取 B 的更新，向 `origin` 推送自己的提交。[GitHub 的远程仓库配置说明](https://docs.github.com/zh/pull-requests/how-tos/work-with-forks/configuring-a-remote-repository-for-a-fork)

## 3. 从 B 指定的 SHA 建立开发分支和工作树

向 B 取得这轮的**完整 Commit SHA**。它是某次提交的 40 位编号，D 和 E 要使用同一个。B 仓库的 `main` 在这份本地克隆里记为 `upstream/main`。

在第 2 步的 `GGGGGame` 克隆目录中运行下面几行。第一行取回 B 的提交。第二行提示你粘贴 SHA 并按回车。最后两行检查这个 SHA 是否在上游 `main` 的历史中，看到 `0` 才继续，其他结果请和 B 核对。

```powershell
git fetch upstream
$BaseSha = (Read-Host '粘贴 B 给你的完整 Commit SHA').Trim()
git merge-base --is-ancestor "$BaseSha" upstream/main
$LASTEXITCODE
```

在**同一个 PowerShell 窗口、同一个克隆目录**按角色只选一组。分支和目录名称是示例，可以换成你与 B 约定的名称。工作树是单独存放该分支文件的目录。

**D（玩家侧）**

```powershell
git worktree add -b d/player-p0-p1 '../GGGGGame-D' "$BaseSha"
Set-Location -LiteralPath '../GGGGGame-D'
```

**E（运输侧）**

```powershell
git worktree add -b e/transport-p0-p1 '../GGGGGame-E' "$BaseSha"
Set-Location -LiteralPath '../GGGGGame-E'
```

`git worktree add -b` 从指定提交创建分支，并把新工作树切到该分支。下一行把 PowerShell 切到新工作树。现在检查当前分支、起点和目录。

```powershell
git branch --show-current
git rev-parse HEAD
Get-Location
```

分支名和你选的一致、SHA 与 B 给出的完整值一致，就可以开工。记下 `Get-Location` 打印的完整目录，下次继续时直接打开这个目录。功能改动在这里做，`main` 留作同步 B 的代码，这样 PR 的改动也更容易检查。

## 4. 把工作树交给 Agent

在 DSH 或 Codex 中打开第 3 步记下的工作树文件夹作为本地项目。若从终端启动 Agent，就先进入工作树目录再启动。把 B 的派发任务、共同 SHA 和分支名一并发给 Agent，先让它核对当前目录和分支。[Codex 的本地项目说明](https://learn.chatgpt.com/docs/projects#use-local-projects-for-folders-and-codebases)

两人都要先读仓库根目录的通用规范。[AGENTS.md](../../AGENTS.md)

- **D** 阅读本方文件。[D Agent 工作规范](D_Agent工作规范.md) · [D 任务书](D_独立功能实现.md) · [D 开发与验收清单](D_开发与验收清单.md)
- **E** 阅读本方文件。[E Agent 工作规范](E_Agent工作规范.md) · [E 任务书](E_独立功能实现.md) · [E 开发与验收清单](E_开发与验收清单.md)

首轮只做 P0/P1。Agent 必须在本方分支开发，改动限本方模块和本次派发，涉及共享或其他成员模块时先交 B 协调。

**D 可复制给 DSH**

> 请核对我指定的 D 工作树、玩家侧分支和 B 给出的共同 SHA，读根目录 AGENTS.md 及 D 的规范、任务书和验收清单，按 B 的派发只完成玩家侧 P0/P1，改动限 D 本轮范围。

**E 可复制给 Codex**

> 请核对我指定的 E 工作树、运输侧分支和 B 给出的共同 SHA，读根目录 AGENTS.md 及 E 的规范、任务书和验收清单，按 B 的派发只完成运输侧 P0/P1，改动限 E 本轮范围。

## 5. 检查、Commit、Push，再开 PR

### 在本方工作树检查和提交

1. 运行 `git branch --show-current`，确认是本方功能分支。用 `git status --short` 查看改动和新增文件，再用 `git diff` 看未暂存的已跟踪文件有哪些改动。遇到分页界面按 `q` 退出。
2. 运行 `git add -- '替换为你确认过的相对文件路径'`，把确定要提交的文件放进待提交清单。有多个文件就按路径逐个加入。
3. 运行 `git diff --cached`，核对待提交的内容，包括新文件。再运行 `git diff --cached --check`，有格式错误先解决。
4. 运行 `git commit -m '简短概括本次改动'`，给这次记录写一句说明。用 `git log -1 --oneline` 看到新提交就成功了。首次提交若提示缺少署名或邮箱，在工作树内分别用 `git config --local user.name '你的提交署名'` 和 `git config --local user.email '你的提交邮箱'` 设置后再重试。

### 推送到自己的 Fork

在同一工作树中再用 `git remote -v` 核对 `origin` 是自己的 Fork，再运行下面的命令。

```powershell
git push -u origin HEAD
```

`HEAD` 在这里指当前功能分支。命令把它推到自己 Fork 上的同名分支。若弹出登录提示，用自己的 GitHub 账号完成验证。到自己 Fork 的网页，用分支下拉框选本方功能分支，能看到刚才的提交即成功。

### 在 GitHub 网页开 PR

1. 打开 **B 的原仓库**，点击 **Pull requests → New pull request**。若仓库首页有 **Compare & pull request**，也可点它。
2. 在比较页面点 **compare across forks**，核对下面四项。

   - **base repository（目标仓库）** 选 `bydgs5418823/GGGGGame`，**base（目标分支）** 选 `main`。
   - **head repository（来源仓库）** 选自己的 Fork，**compare（来源分支）** 选自己刚推送的功能分支。

   ```text
   D/E 自己的 Fork（自己的功能分支） ── PR ──▶ bydgs5418823/GGGGGame（main）
   ```

3. 核对页面列出的文件和提交。点 **Create pull request**，填标题和说明，再点 **Create pull request** 提交。说明写明共同基线 SHA、任务编号、改动范围、运行和 CI 证据、已知问题及未执行项。
4. 看到 PR 编号和 **Open** 状态即成功。把链接交给对方互审，再请 B 审查。B 审查通过并执行合并后，修改才进入原仓库的 `main`。[GitHub 的 Fork PR 操作说明](https://docs.github.com/zh/pull-requests/how-tos/create-pull-requests/creating-a-pull-request-from-a-fork)

## 6. 同步 B 的最新代码

B 合并其他 PR 后，上游 `main` 有了新提交，你的 Fork 可能还停在旧提交。可以用下列两种方式之一同步 `main`。涉及 PowerShell 的命令都先回第 2 步的 `GGGGGame` 克隆目录，运行 `git status --short` 确认没有待处理文件，再用 `git switch main` 切到本地 `main`。

**用网页同步。** 在自己的 Fork 页面选择 `main`，点 **Sync fork → Update branch**。网页显示已与上游同步后，在本地克隆目录运行 `git pull --ff-only origin main`，把 Fork 的更新取到电脑。运行 `git rev-parse main origin/main`，两行 SHA 相同说明本地与 Fork 的 `main` 一致。[GitHub 的同步 Fork 操作说明](https://docs.github.com/zh/pull-requests/how-tos/work-with-forks/syncing-a-fork)

**用命令同步。** 在已切到 `main` 的克隆目录中，取回 B 的提交并更新本地 `main`。这里的 `--ff-only` 只允许沿现有历史向前更新。遇到报错先停下。

```powershell
git fetch upstream
git merge --ff-only upstream/main
git rev-parse main upstream/main
```

确认最后一条命令打印的两个 SHA 相同，再运行 `git push origin main` 更新 GitHub 上自己的 Fork。刷新 Fork 的 `main`，看到上游的新提交即成功。

如果 B 确认进行中的功能分支也要更新，回到自己的功能工作树，核对分支并先保存、提交现有工作。工作区干净后运行 `git fetch upstream` 和 `git merge --no-edit upstream/main`。合并成功后，按本方清单复测。需要更新已有 PR 时，把新提交推到同一功能分支即可。

发生冲突时，先保留工作区并暂停后续命令。用 `git status` 找到冲突文件，让 Agent 说明两边各改了什么、提议如何保留修改。涉及共享或对方模块的冲突由 B 协调，确认后再处理。网页若提示放弃提交，也先停下。项目禁止使用 `git reset --hard`、`git clean -fd` 和强制推送（如 `git push --force`）。含有未提交修改的文件夹要保留。

## 新手常见问题

- **Fork 会影响 B 的原始仓库吗？** 不会。Fork 会在你的账号下新增仓库，B 的原仓库保持原样。
- **我修改自己 Fork 里的文件，B 会立刻看到吗？** 本地修改要 Push 后才会出现在 GitHub。有访问权限的人可以主动到 Fork 查看。开 PR 并发链接，B 就有了审查入口。
- **为什么要先 Fork 再创建 Branch？** Fork 给你一个可以推送到的 GitHub 仓库。Branch 给本次任务一条独立的开发线。
- **D/E 能同时开发吗？** 能。两人从 B 指定的同一 SHA 在各自的工作树和分支上推进，按分工提交。
- **如何把完成的代码交给 B？** Commit 后 Push 到自己的 Fork，在 B 的原仓库开一个以 `main` 为目标的 PR，把链接交给 B。
- **B 合并 PR 后，我还需要做什么？** 在 PR 页面确认状态是 **Merged**，同步自己 Fork 和本地的 `main`，下一轮按 B 给出的基线开工。
- **Agent 能自动帮我执行这些操作吗？** 可以在你授权后帮你运行 Git 命令。你负责登录自己的账号，理解每一步，并核对待提交文件、推送地址和 PR 方向。
- **Git 提示冲突或没有权限怎么办？** 冲突按第 6 步保留现场。权限问题先用 `git remote -v` 核对地址和仓库所有者，再确认 Git 用的是你本人的 GitHub 登录凭据。若打不开原仓库或无法 Fork，把报错发给 B 核对访问权限。
