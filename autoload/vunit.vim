" Author:  Eric Van Dewoestine
"
" Description: {{{
"   Plugin providing junit like framework for unit testing vim scripts.
"   Initially inspired by vim_unit.vim by Staale Flock:
"     http://www.vim.org/scripts/script.php?script_id=1125
"
" License:
"   Copyright (c) 2005 - 2024, Eric Van Dewoestine
"   All rights reserved.
"
"   Redistribution and use of this software in source and binary forms, with
"   or without modification, are permitted provided that the following
"   conditions are met:
"
"   * Redistributions of source code must retain the above
"     copyright notice, this list of conditions and the
"     following disclaimer.
"
"   * Redistributions in binary form must reproduce the above
"     copyright notice, this list of conditions and the
"     following disclaimer in the documentation and/or other
"     materials provided with the distribution.
"
"   * Neither the name of Eric Van Dewoestine nor the names of its
"     contributors may be used to endorse or promote products derived from
"     this software without specific prior written permission of
"     Eric Van Dewoestine.
"
"   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
"   IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
"   THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
"   PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
"   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
"   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
"   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
"   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
"   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
"   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
"   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
" }}}

if v:version < 700
  finish
endif

let s:save_cpo=&cpo
set cpo&vim

" Global Variables {{{
  if !exists('g:VUnitTestsDir')
    " Sets the directory where vunit tests can be found
    let g:VUnitTestsDir = 'test'
  endif
  if !exists('g:VUnitResultsDir')
    " Sets the output directory where test results will be written to.
    let g:VUnitResultsDir = 'build/test'
  endif
  if !exists('g:VUnitPluginDir')
    " Sets the directory where the plugin(s) to test are located
    let g:VUnitPluginDir = 'plugin'
  endif
" }}}

" Script Variables {{{
  let s:function_regex = '^\s*fu\%[nction]\%[!]\s\+\(.\{-}\)\s*(\s*).*$'
  let s:non_failure_regex = '^\%(\%(^Fail.*$\)\@!.\)*$'

  let s:testsuite = '<testsuite name="<suite>" tests="<tests>" failures="<failures>" time="<time>">'
  let s:testcase = '  <testcase classname="<testcase>" name="<test>" time="<time>"'
" }}}

function! vunit#Vunit(bang, ...) " {{{
  let result = findfile('autoload/vunit.vim', escape(&rtp, ' '))
  if result == ''
    call s:Echo('Unable to locate vunit in the runtimepath.', 'error')
    return
  endif

  let path = fnamemodify(result, ':h:h')
  let vunit = path . '/bin/vunit'
  if !filereadable(vunit)
    call s:Echo('Unable to locate vunit script.', 'error')
    return
  endif

  let results_dir = g:VUnitResultsDir
  let tests = len(a:000) ? a:000 : [g:VUnitTestsDir . '/**/*.vim']

  let rtp = getcwd()
  if exists('g:VUnitRuntimePath')
    let rtp = g:VUnitRuntimePath
  else
    let rtp = getcwd()
  endif

  let cmd = vunit .
    \ ' -d ' . results_dir .
    \ ' -r ' . rtp .
    \ ' -p ' . g:VUnitPluginDir . '/*.vim' .
    \ ' -t ' . join(tests, ' -t ')

  let orig_makeprg = &makeprg
  let orig_erroformat = &errorformat
  try
    exec 'set makeprg=' . escape(cmd, ' ')
    exec 'set errorformat=' .
      \ '%EFAIL:\ %f:%l,%Z\ \ %m,' .
      \ '%-GRunning:%.%#,' .
      \ '%-GTests\ run:%.%#,' .
      \ '%-G%.%#FAILED'
    exec 'make' . a:bang
    " probably a way to eliminate these leading newline chars using the
    " errorformat, but so far no luck
    let results = getqflist()
    for result in results
      let result['text'] = substitute(result['text'], '^\n', '', '')
    endfor
    call setqflist(results, 'r')
    call setqflist([], 'r', {'title': 'VUnit'})
  finally
    let &makeprg = orig_makeprg
    let &errorformat = orig_erroformat
  endtry
endfunction " }}}

function! vunit#AssertEquals(arg1, arg2, ...) " {{{
  " Compares the two arguments to determine if they are equal.
  if a:arg1 != a:arg2
    let message = string(a:arg1) . ' != ' . string(a:arg2)
    if a:0 > 0
      let message = a:1 . ' (' . message . ')'
    endif
    throw 'AssertEquals: ' . message
  endif
endfunction " }}}

function! vunit#AssertNotEquals(arg1, arg2, ...) " {{{
  " Compares the two arguments to determine if they are equal.
  if a:arg1 == a:arg2
    let message = string(a:arg1) . ' == ' . string(a:arg2)
    if a:0 > 0
      let message = a:1 . ' (' . message . ')'
    endif
    throw 'AssertNotEquals: ' . message
  endif
endfunction " }}}

function! vunit#AssertTrue(arg1, ...) " {{{
  " Determines if the supplied argument is true.
  if !a:arg1
    let message = string(a:arg1) . ' is not true.'
    if a:0 > 0
      let message = a:1 . ' (' . message . ')'
    endif
    throw 'AssertTrue: ' . message
  endif
endfunction " }}}

function! vunit#AssertFalse(arg1, ...) " {{{
  " Determines if the supplied argument is false.
  if a:arg1 || type(a:arg1) != 0
    let message = string(a:arg1) . ' is not false.'
    if a:0 > 0
      let message = a:1 . ' (' . message . ')'
    endif
    throw 'AssertFalse: ' . message
  endif
endfunction " }}}

function! vunit#Fail(...) " {{{
  " Fails the current test.
  let message = a:0 > 0 ? a:1 : ''
  throw 'Fail: ' . message
endfunction " }}}

function! vunit#TestRunner(basedir, testfile) " {{{
  " Runs the supplied test case.
  " basedir - The base directory where the file is located.  Used to construct
  "           the output file (testfile with basedir stripped off).
  " testfile - The basedir relative test file to run.

  let resultsfile = s:Init(a:basedir, a:testfile)
  if resultsfile == ''
    return
  endif

  let testfile = fnamemodify(a:basedir . '/' . a:testfile, ':p')
  exec 'source ' . testfile
  let tests = s:GetTestFunctionNames(testfile)

  call vunit#PushRedir('=>> g:vu_sysout')

  if exists('*BeforeTestCase')
    call BeforeTestCase()
  endif

  let now = localtime()
  let testcase = fnamemodify(a:testfile, ':r')
  for [test, line] in tests
    call s:RunTest(testcase, test, line)
  endfor

  if exists('*AfterTestCase')
    call AfterTestCase()
  endif

  call vunit#PopRedir()

  let duration = localtime() - now
  call s:WriteResults(a:testfile, resultsfile, duration)

  echom printf(
    \ 'Tests run: %s, Failures: %s, Time elapsed %s sec',
    \ s:tests_run, s:tests_failed, duration)

  if s:tests_failed > 0
    echom "Test " . a:testfile . " FAILED"
  endif
endfunction " }}}

function! vunit#PushRedir(redir) " {{{
  exec 'redir ' . a:redir
  call add(s:redir_stack, a:redir)
endfunction " }}}

function! vunit#PopRedir() " {{{
  let index = len(s:redir_stack) - 2
  if index >= 0
    let redir = s:redir_stack[index]
    exec 'redir ' . redir
    call remove(s:redir_stack, index + 1, len(s:redir_stack) - 1)
  else
    let s:redir_stack = []
    redir END
  endif
endfunction " }}}

function! vunit#PeekRedir() " {{{
  call vunit#PushRedir(s:redir_stack[len(s:redir_stack) - 1])
  call vunit#PopRedir()
  return s:redir_stack[len(s:redir_stack) - 1]
endfunction " }}}

function! s:Init(basedir, testfile) " {{{
  let s:tests_cwd = getcwd()
  let s:tests_run = 0
  let s:tests_failed = 0
  let s:suite_methods = []
  let s:test_results = []
  let s:redir_stack = []
  let g:vu_sysout = ''

  silent! delfunction BeforeTestCase
  silent! delfunction SetUp
  silent! delfunction TearDown
  silent! delfunction AfterTestCase

  " construct output file to use.
  let file = a:testfile

  " remove file extension
  let file = fnamemodify(file, ':r')
  " remove spaces, leading path separator, and drive letter
  let file = substitute(file, '\(\s\|^[a-zA-Z]:/\|^/\)', '', 'g')
  " substitute all path separators with '.'
  let file = substitute(file, '\(/\|\\\)', '.', 'g')

  let resultsfile = g:VUnitResultsDir . '/TEST-' . file . '.xml'

  " delete the existing file
  call delete(resultsfile)

  return resultsfile
endfunction " }}}

function! s:RunTest(testcase, test, line) " {{{
  let now = localtime()
  if exists('*SetUp')
    call SetUp()
  endif

  let file = ''
  let line = 1
  let failure = ''
  let stack = []
  let sid = expand('<SID>')
  let scripts = []
  try
    call {a:test}()
    let s:tests_run += 1
    if exists('*TearDown')
      call TearDown()
    endif
  catch
    if len(scripts) == 0
      let scripts = getscriptinfo()
    endif
    let s:tests_run += 1
    let s:tests_failed += 1
    let failure = v:exception
    for location in split(v:throwpoint, '\.\.')
      if location =~ '\(^command line$\|\<vunit#[A-Z]\|' . sid . '\)'
        continue
      endif
      let [location, file, line] = s:FailureLocation(
        \ a:testcase,
        \ location,
        \ scripts
      \ )
      call add(stack, location)
    endfor
  endtry

  let time = localtime() - now
  let result = {
      \ 'testcase': a:testcase,
      \ 'test': a:test,
      \ 'file': file,
      \ 'line': line,
      \ 'time': time,
      \ 'failure': failure,
      \ 'stack': stack,
    \ }
  call add(s:test_results, result)
  call s:TearDown()
endfunction " }}}

function! s:FailureLocation(testcase, location, scripts) " {{{
  let location = substitute(a:location, '\[\(\d\+\)\]$', ', line \1', '')
  let line = substitute(location, '.*, line \(\d\+\)$', '\1', '')

  let file = ''
  let func = substitute(location, ', line .*', '', '')
  for script in a:scripts
    let script = getscriptinfo({'sid': script['sid']})[0]
    if index(script['functions'], func) != -1
      let file = script['name']
      break
    endif
  endfor

  let cwd = getcwd() . '/'
  if file =~ '^' . cwd
    let file = substitute(file, cwd, '', '')
  endif

  silent exec 'split ' . file
  try
    call cursor(1, 1)
    let func = substitute(func, '^\(<SNR>\d\+_\)', 's:', '')
    let line += search('fun\?c\?t\?i\?o\?n\?!\?\s\+' . func, 'c')
  finally
    bdelete
  endtry

  let location = substitute(location, '^\(<SNR>\d\+_\)', 's:', '')
  return [location, file, line]
endfunction " }}}

function! s:TearDown() " {{{
  " restore orig cwd
  exec 'cd ' . escape(s:tests_cwd, ' ')

  " dispose of all buffers
  let lastbuf = bufnr('$')
  let curbuf = 1

  let g:null = ''
  call vunit#PushRedir('=> g:null')
  while curbuf <= lastbuf
    exec 'silent! bwipeout! ' . curbuf
    let curbuf += 1
  endwhile

  " this will really make sure we are not re-using an existing buffer
  let curbuf = bufnr('%')
  new
  exec 'silent! bwipeout! ' . curbuf

  " reset the syntax
  syntax off | syntax clear | syntax on

  call vunit#PopRedir()
  unlet g:null
endfunction " }}}

function! s:GetTestFunctionNames(testfile) " {{{
  let winreset = winrestcmd()
  let results = []

  new
  try
    silent exec 'view ' . a:testfile
    call cursor(1, 1)

    while search(s:function_regex, 'cW')
      let name = substitute(getline('.'), s:function_regex, '\1', '')
      if name == 'Suite'
        call Suite()
        return s:suite_methods
      endif

      if name =~ '^Test'
        call add(results, [name, line('.')])
      endif
      call cursor(line('.') + 1, 1)
    endwhile

  finally
    bdelete!
    exec winreset
  endtry
  return results
endfunction " }}}

function! s:WriteResults(testfile, resultsfile, running_time) " {{{
  let root = s:testsuite
  let root = substitute(root, '<suite>', a:testfile, '')
  let root = substitute(root, '<tests>', s:tests_run, '')
  let root = substitute(root, '<failures>', s:tests_failed, '')
  let root = substitute(root, '<time>', a:running_time, '')
  let results = [
    \ '<?xml version="1.0" encoding="UTF-8" ?>',
    \ root,
    \ '  <system-out>',
    \ '    <![CDATA[',
    \ '    ]]>',
    \ '  </system-out>',
    \ '</testsuite>']

  " insert test results
  let index = -5
  for result in s:test_results
    let testcase = s:testcase
    let testcase = substitute(testcase, '<testcase>', result.testcase, '')
    let testcase = substitute(testcase, '<test>', result.test, '')
    let testcase = substitute(testcase, '<time>', result.time, '')
    let testcase .= result.failure != '' ? '>' : '/>'

    call insert(results, testcase, index)

    echom 'result:' result
    if result.failure != ''
      echom 'result.failure:' result.failure
      let message = result.failure
      let message = substitute(message, '&', '\&amp;', 'g')
      let message = substitute(message, '"', '\&quot;', 'g')
      let message = substitute(message, '<', '\&lt;', 'g')
      let message = substitute(message, '>', '\&gt;', 'g')
      let failure_tag = '<failure' .
        \ ' file="' . result.file . '"' .
        \ ' line="' . result.line . '"' .
        \ ' message="' . message . '">'
      call insert(results, '    ' . failure_tag . '<![CDATA[', index)
      call insert(results, '      <![CDATA[', index)
      for location in result.stack
        call insert(results, location, index)
      endfor
      call insert(results, '      ]]>', index)
      call insert(results, '    </failure>', index)
      call insert(results, '  </testcase>', index)
    endif
  endfor

  " insert system output
  let out = split(g:vu_sysout, '\n')
  call map(out, '"    " . v:val')
  let index = -3
  for line in out
    call insert(results, line, index)
  endfor

  call writefile(results, a:resultsfile)
endfunction " }}}

function! s:Echo(message, level) " {{{
  let highlight = 'Statement'
  if a:level == 'warning'
    let highlight = 'WarningMsg'
  elseif a:level == 'error'
    let highlight = 'Error'
  endif

  exec "echohl " . highlight
  redraw
  for line in split(a:message, '\n')
    echom line
  endfor
  echohl None
endfunction " }}}

let &cpo = s:save_cpo

" vim:ft=vim:fdm=marker
