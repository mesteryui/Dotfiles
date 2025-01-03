return {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function() -- Definimos la tabla que lleva la configuracion
    require('lualine').setup({
    options = {
      theme = 'catppuccin'
}})
  end
}

