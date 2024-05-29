function TestFailure()
  call vunit#AssertEquals('yes', 'yes')
  call vunit#AssertEquals('yes', 'no')
endfunction

function TestErrorAutoload()
  " found in test/autoload/vunit/test.vim
  call vunit#test#Autoload()
endfunction

function TestErrorScript()
  " found in test/autoload/vunit/test.vim
  call vunit#test#AutoloadScript()
endfunction
