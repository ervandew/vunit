function TestNestedFailure()
  call vunit#AssertEquals('yes', 'no')
endfunction
