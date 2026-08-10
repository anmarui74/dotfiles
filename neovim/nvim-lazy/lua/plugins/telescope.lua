return {
  "nvim-telescope/telescope.nvim",
  event = "VeryLazy",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope-file-browser.nvim",
    {
      "nvim-telescope/telescope-fzf-native.nvim",
      build = "make",
    },
  },
  opts = {
    estensions = {
      fzf = {
        fuzxzy = true,
        override_generic_sorter = true,
        override_file_sorter = true,
        case_mose = "smart_case",
      },
    },
  },
  config = function(opts)
    require("telescope").setup(opts)
    require("telescope").load_extension("fzf")
  end,
  require("telescope").setup({
    defaults = {
      -- Estrategia visual: "horizontal" (por defecto), "vertical", "center" o "flex"
      layout_strategy = "horizontal",
      layout_config = {
        -- Dimensiones globales (0.80 significa 80% de la pantalla)
        width = 0.90, -- Ancho total de la ventana de Telescope
        height = 0.85, -- Alto total de la ventana de Telescope
        -- Control de la vista previa (Preview)
        preview_width = 0.50, -- El 50% del ancho total será para la vista previa
        preview_cutoff = 120, -- Si la pantalla mide menos de 120 columnas, oculta la vista previa
        -- Posición de la barra de búsqueda y elementos internos
        prompt_position = "bottom", -- Coloca el buscador arriba ("top") o abajo ("bottom")
      },
      -- Configuración para que el prompt arriba funcione correctamente
      sorting_strategy = "ascending",
    },
  }),
  keys = {
    {
      "<leader>tf",
      function()
        require("telescope.builtin").find_files()
      end,
      desc = "Telescope Find Files",
    },
    {
      "<leader>th",
      function()
        require("telescope.builtin").help_tags()
      end,
      desc = "Telescope Help",
    },
    {
      "<leader>tb",
      function()
        require("telescope").extensions.file_browser.file_browser({
          path = "%:h:p",
          select_buffer = true,
          sorting_strategy = "ascending",
          grouped = true,
        })
      end,
      desc = "Telescope file browser",
    },
  },
}
