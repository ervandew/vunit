function! vunit#test#Autoload()
  error autoload
endfunction

function! vunit#test#AutoloadScript()
  call s:Script()
endfunction

function! s:Script()
  error script
endfunction
