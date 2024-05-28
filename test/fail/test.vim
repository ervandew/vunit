function TestFailure()
  call vunit#AssertEquals('yes', 'yes')
  call vunit#AssertEquals('yes', 'no')
endfunction
