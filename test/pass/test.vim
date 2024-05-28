function SetUp()
  let s:setup = 1
endfunction

function TestSetUp()
  call vunit#AssertEquals(s:setup, 1)
endfunction

function TestAssertEquals()
  call vunit#AssertEquals('yes', 'yes')
  try
    call vunit#AssertEquals('yes', 'no')
    call vunit#Fail('Equals should have raised an error')
  catch /AssertEquals.*/
    call vunit#AssertEquals(v:exception, "AssertEquals: 'yes' != 'no'")
  endtry
endfunction

function TestAssertNotEquals()
  call vunit#AssertNotEquals('yes', 'no')
  try
    call vunit#AssertNotEquals('yes', 'yes')
    call vunit#Fail('Not Equals should have raised an error')
  catch /AssertNotEquals.*/
    call vunit#AssertEquals(v:exception, "AssertNotEquals: 'yes' == 'yes'")
  endtry
endfunction

function TestAssertTrue()
  call vunit#AssertTrue('yes' == 'yes')
  try
    call vunit#AssertTrue('yes' == 'no')
    call vunit#Fail('True should have raised an error')
  catch /AssertTrue.*/
    call vunit#AssertEquals(v:exception, "AssertTrue: 0 is not true.")
  endtry
endfunction

function TestAssertFalse()
  call vunit#AssertFalse('yes' == 'no')
  try
    call vunit#AssertFalse('yes' == 'yes')
    call vunit#Fail('False should have raised an error')
  catch /AssertFalse.*/
    call vunit#AssertEquals(v:exception, "AssertFalse: 1 is not false.")
  endtry
endfunction

function TestFail()
  try
    call vunit#Fail('test fail')
  catch /Fail.*/
    call vunit#AssertEquals(v:exception, "Fail: test fail")
  endtry
endfunction

function TestVunit()
  let bufnr = bufnr()

  try
    Vunit test/fail

    let results = getqflist()
    call vunit#AssertEquals(len(results), 2)
    call vunit#AssertTrue(results[0]['bufnr'] > 1)
    call vunit#AssertEquals(results[0]['lnum'], 3)
    call vunit#AssertEquals(
      \ results[0]['text'],
      \ 'TestFailure AssertEquals: ''yes'' != ''no'''
    \ )
    exec results[0]['bufnr'] . 'buffer'
    call vunit#AssertEquals(expand('%'), 'test/fail/test.vim')

    call vunit#AssertTrue(results[1]['bufnr'] > 1)
    call vunit#AssertEquals(results[1]['lnum'], 2)
    call vunit#AssertEquals(
      \ results[1]['text'],
      \ 'TestNestedFailure AssertEquals: ''yes'' != ''no'''
    \ )
    exec results[1]['bufnr'] . 'buffer'
    call vunit#AssertEquals(expand('%'), 'test/fail/nested/test.vim')

    Vunit %
    let results = getqflist()
    call vunit#AssertEquals(len(results), 1)
    call vunit#AssertEquals(results[0]['bufnr'], bufnr())
    call vunit#AssertEquals(results[0]['lnum'], 2)
    call vunit#AssertEquals(
      \ results[0]['text'],
      \ 'TestNestedFailure AssertEquals: ''yes'' != ''no'''
    \ )
    call vunit#AssertEquals(expand('%'), 'test/fail/nested/test.vim')
    call vunit#AssertEquals(line('.'), 2)

    Vunit test/fail/test.vim
    let results = getqflist()
    call vunit#AssertEquals(len(results), 1)
    call vunit#AssertTrue(results[0]['bufnr'], bufnr())
    call vunit#AssertEquals(results[0]['lnum'], 3)
    call vunit#AssertEquals(
      \ results[0]['text'],
      \ 'TestFailure AssertEquals: ''yes'' != ''no'''
    \ )
    call vunit#AssertEquals(expand('%'), 'test/fail/test.vim')
    call vunit#AssertEquals(line('.'), 3)
  finally
    exec bufnr . 'buffer'
  endtry
endfunction
