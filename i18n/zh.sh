#!/usr/bin/env bash
# 中文语言字符串

# 横幅
MSG_BANNER_TITLE="智能个人助手"
MSG_BANNER_SUBTITLE="AI 驱动的个人生活管理系统"

# 已有配置
MSG_EXISTING_FOUND="发现已有配置"
MSG_EXISTING_LOADING="正在加载之前的设置..."
MSG_EXISTING_START_FRESH="全新安装"

# 系统检查
MSG_SYSTEM_CHECK="系统检查"
MSG_PYTHON_NOT_FOUND="未找到 Python 3"
MSG_PIP_AVAILABLE="pip 可用"
MSG_PIP_NOT_FOUND="未找到 pip — 安装依赖时需要"
MSG_CLAUDE_NOT_FOUND="未找到 Claude CLI"
MSG_CONTINUE_WITHOUT="没有 Claude CLI 继续吗？"

# 模式
MSG_MODE_TITLE="运行模式"
MSG_MODE_DAEMON="守护进程模式（推荐）— 每天约 15-20K tokens"
MSG_MODE_COWORK="Cowork 模式 — 每天约 60-80K tokens"

# 身份
MSG_IDENTITY_TITLE="关于你"
MSG_IDENTITY_NAME="我该怎么称呼你？"
MSG_IDENTITY_ASSISTANT="给你的助手起个名字："

# AI 提供者
MSG_LLM_TITLE="AI 提供者"
MSG_LLM_CLAUDE="Claude (Anthropic) — 使用 Pro/Max 订阅（推荐）"
MSG_LLM_OLLAMA="Ollama — 免费，本地运行（即将支持）"
MSG_LLM_CUSTOM="自定义 — 任何 OpenAI 兼容接口（即将支持）"

# 聊天频道
MSG_CHANNEL_TITLE="聊天频道"
MSG_CHANNEL_CURRENT="当前 Slack 配置："
MSG_CHANNEL_CHANGE="要修改 Slack 配置吗？"
MSG_CHANNEL_KEEPING="保持现有 Slack 配置"
MSG_CHANNEL_SLACK="Slack（推荐）"
MSG_CHANNEL_DISCORD="Discord（即将支持）"
MSG_CHANNEL_TELEGRAM="Telegram（即将支持）"

# Slack 设置
MSG_SLACK_TITLE="Slack 应用设置"
MSG_SLACK_STEP1="第 1/3 步：创建 Slack 应用"
MSG_SLACK_OPEN_AUTO="正在打开 Slack，所有权限已预填..."
MSG_SLACK_SELECT_AUTO="选择你的工作区 → 下一步 → 创建"
MSG_SLACK_FALLBACK="如果 Slack 显示错误，请选择"从应用清单创建"，"
MSG_SLACK_FALLBACK2="切换到 JSON 标签页，粘贴以下文件内容："
MSG_SLACK_OPEN_MANUAL="正在打开 Slack 应用创建页面..."
MSG_SLACK_MANUAL_MANIFEST="选择"从应用清单创建" → 选择工作区 → 下一步"
MSG_SLACK_MANUAL_JSON="切换到 JSON 标签页，粘贴以下文件内容："
MSG_SLACK_MANUAL_CREATE="点击"下一步" → "创建""
MSG_SLACK_STEP2="第 2/3 步：安装并复制 Token"
MSG_SLACK_INSTALL="在左侧栏点击 'OAuth & Permissions'"
MSG_SLACK_INSTALL2="点击 'Install to Workspace' → 'Allow'"
MSG_SLACK_INSTALL3="复制 'Bot User OAuth Token'（以 xoxb- 开头）"
MSG_SLACK_PASTE="粘贴你的 Bot Token："
MSG_SLACK_TOKEN_WARN="Token 不是以 'xoxb-' 开头 — 请确认复制的是 Bot Token"
MSG_SLACK_STEP3="第 3/3 步：设置频道"
MSG_SLACK_CHANNEL_CREATE="创建一个频道（如 #my-cowork）或使用现有频道"
MSG_SLACK_CHANNEL_INVITE="邀请机器人："
MSG_SLACK_CHANNEL_ID_HINT="获取频道 ID：右键点击频道 → 查看详情 → 页面底部"
MSG_SLACK_CHANNEL_ID="频道 ID（以 C 开头）："
MSG_SLACK_CHANNEL_NAME="频道名称："
MSG_SLACK_DONE="Slack 配置完成！"

# Slack 测试
MSG_SLACK_TEST="测试 Slack 连接？"
MSG_SLACK_TEST_SENDING="正在发送测试消息..."
MSG_SLACK_TEST_OK="测试消息已发送！请检查你的频道。"
MSG_SLACK_TEST_FAIL="无法发送消息。"
MSG_SLACK_TEST_DEBUG="排查步骤："
MSG_SLACK_TEST_DEBUG1="1. 应用是否已安装到工作区？（OAuth & Permissions → Install）"
MSG_SLACK_TEST_DEBUG2="2. Bot Token 是否正确？（应以 xoxb- 开头）"
MSG_SLACK_TEST_DEBUG3="3. 是否添加了所有权限？（channels:history, chat:write 等）"
MSG_SLACK_TEST_DEBUG4="4. 频道 ID 是否正确？（右键频道 → 查看详情 → 底部）"
MSG_SLACK_TEST_DEBUG5="5. 机器人是否已被邀请到频道？（在频道中输入 /invite @机器人名）"
MSG_SLACK_TEST_RETRY="修复后重试？"
MSG_SLACK_TEST_MSG="你好！你的智能助手已连接，准备就绪。"

# Slack cowork
MSG_SLACK_COWORK="Cowork 模式使用 Claude 内置的 Slack MCP。"
MSG_SLACK_COWORK2="只需要频道信息。"

# 存储和时区
MSG_PROFILE_TITLE="存储位置 & 时区"
MSG_PROFILE_TIMEZONE="时区："
MSG_PROFILE_FOLDER="文件存储在哪里？"
MSG_PROFILE_FOLDER_HINT="使用云文件夹可以在手机上用 Obsidian 查看，也方便家人共享。"
MSG_PROFILE_FOLDER_CURRENT="文件夹："
MSG_PROFILE_ICLOUD="iCloud (Obsidian 仓库) — 最佳手机访问 + 家人共享"
MSG_PROFILE_ICLOUD_DOCS="iCloud 文稿 — 苹果设备同步"
MSG_PROFILE_DROPBOX="Dropbox — 跨平台同步"
MSG_PROFILE_GDRIVE="Google Drive — 跨平台同步"
MSG_PROFILE_ONEDRIVE="OneDrive — 跨平台同步"
MSG_PROFILE_LOCAL="仅本地 — ~/Documents/Personal Assistant"
MSG_PROFILE_CUSTOM="自定义路径"
MSG_PROFILE_ENTER_PATH="输入完整路径："

# 家庭扩展
MSG_FAMILY_TITLE="家庭扩展（可选）"
MSG_FAMILY_CURRENT="当前家庭设置："
MSG_FAMILY_CHANGE="要修改家庭配置吗？"
MSG_FAMILY_KEEPING="保持现有家庭设置"
MSG_FAMILY_CONFIRM="要给家人也设置一个吗？"
MSG_FAMILY_NAME="他/她的名字："
MSG_FAMILY_CHANNEL="他/她的 Slack 频道 ID："
MSG_FAMILY_CHANNEL_NAME="频道名称："
MSG_FAMILY_FOLDER="他/她的文件夹："

# 文件生成
MSG_GENERATING="生成文件"
MSG_ALREADY_EXISTS="已存在 — 跳过"
MSG_FRAMEWORK_DONE="框架文件已复制到："
MSG_FRAMEWORK_HINT="你的日程和项目会在 AI 首次连接时通过对话设置。"

# 安装依赖
MSG_DEPS_TITLE="安装依赖"
MSG_DEPS_VENV="虚拟环境：.venv/"
MSG_DEPS_INSTALLED="Python 依赖已安装"
MSG_DEPS_FAIL="无法自动安装，请手动运行："
MSG_DEPS_ENV=".env 已更新（Bot Token 已保存）"

# 守护进程
MSG_DAEMON_TITLE="启动守护进程"
MSG_DAEMON_BG="后台服务（开机自动启动）"
MSG_DAEMON_MANUAL="手动运行（自己执行 ./run.sh）"
MSG_DAEMON_VERIFY="正在验证守护进程是否在运行..."
MSG_DAEMON_RUNNING="守护进程正在运行"
MSG_DAEMON_NOT_RUNNING="守护进程可能未启动，请检查日志："
MSG_DAEMON_MANUAL_START="手动启动："
MSG_DAEMON_MANUAL_VERIFY="验证是否正常："
MSG_DAEMON_ALREADY_RUNNING="守护进程已在运行。"
MSG_DAEMON_RESTART_PROMPT="你想怎么做？"
MSG_DAEMON_RESTART_OPT1="自动重启（更新配置并重启）"
MSG_DAEMON_RESTART_OPT2="仅停止（稍后手动启动）"
MSG_DAEMON_STOPPING="正在停止现有守护进程..."
MSG_DAEMON_STOPPED="守护进程已停止"
MSG_DAEMON_RESTARTING="正在使用更新的配置重启守护进程..."
MSG_DAEMON_MANUAL_REMINDER="守护进程已停止。手动启动："
MSG_DAEMON_FDA_TITLE="检测到 iCloud 笔记文件夹"
MSG_DAEMON_FDA_EXPLAIN="macOS 会阻止后台服务（launchd）访问 iCloud 文件。由于你的笔记在 iCloud 中，守护进程需要从终端运行。"
MSG_DAEMON_FDA_MANUAL="在终端中运行以下命令启动守护进程："
MSG_DAEMON_FDA_TIP="提示：将此命令添加到 shell 配置文件（~/.zshrc）中，可在登录时自动启动。"

# 总结
MSG_SUMMARY_COMPLETE="设置完成！"
MSG_SUMMARY_NEXT="接下来会发生什么："
MSG_SUMMARY_NEXT1="守护进程每分钟检查一次 Slack"
MSG_SUMMARY_NEXT2="首次运行时，AI 会在"
MSG_SUMMARY_NEXT3="中联系你，了解你的日程和项目（约 15 分钟对话）"
MSG_SUMMARY_NEXT4="之后就全自动了 — 日报推送、签到、"
MSG_SUMMARY_NEXT5="提醒，都是自动的"
MSG_SUMMARY_COMMANDS="常用命令："
MSG_SUMMARY_LOG="设置日志保存在："
MSG_SUMMARY_LOG_HINT="遇到问题时，请把这个日志附在 GitHub issue 中。"
MSG_SUMMARY_ENJOY="享受你的 AI 生活管理系统吧！"

# 通用
MSG_DONE="完成了吗？"
MSG_CHOICE="选择："

# 运行脚本
MSG_RUN_STARTING="正在启动智能个人助手..."
MSG_RUN_LOG="日志文件："
MSG_RUN_CREATING_VENV="正在创建虚拟环境..."
MSG_RUN_INSTALLING="正在安装依赖..."
MSG_RUN_MISSING="缺少 Python 依赖："
MSG_RUN_INSTALLING_MISSING="正在安装缺少的依赖："
