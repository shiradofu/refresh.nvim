if exists('g:loaded_refresh_nvim')
  finish
endif

com! RefreshStatus -nargs=1 lua require('refresh').status(<f-args>)

let g:loaded_refresh_nvim = 1
