-- ===========================================================================
-- LLM 配置：CodeCompanion
-- ===========================================================================

local deepseek_adapter = require("codecompanion.adapters.http").extend("deepseek", {
	name = "deepseek",
	url = "https://api.deepseek.com/chat/completions",
	env = { api_key = "DEEPSEEK_API_KEY" },
	schema = {
		model = { default = "deepseek-chat" },
	},
})

require("codecompanion").setup({
	opts = { language = "简体中文" },
	interactions = {
		chat = { adapter = "deepseek" },
		inline = { adapter = "deepseek" },
	},
	adapters = {
		http = {
			opts = { show_presets = false, show_model_choices = false },
			deepseek = deepseek_adapter,
		},
	},
})
