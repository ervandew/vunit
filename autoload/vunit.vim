" Author:  Eric Van Dewoestine
"
" Description: {{{
"   Plugin providing junit like framework for unit testing vim scripts.
"   Initially inspired by vim_unit.vim by Staale Flock:
"     http://www.vim.org/scripts/script.php?script_id=1125
"
" License:
"   Copyright (c) 2005 - 2011, Eric Van Dewoestine
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
  if !exists('g:VUnitOutputDir')
    " Sets the output directory where test results will be written to.
    let g:VUnitOutputDir = '.'
  endif
" }}}

" Script Variables {{{
  let s:function_regex = '^\s*fu\%[nction]\%[!]\s\+\(.\{-}\)\s*(\s*).*$'
  let s:non_failure_regex = '^\%(\%(^Fail.*$\)\@!.\)*$'

  let s:testsuite = '<testsuite name="<suite>" tests="<tests>" failures="<failures>" time="<time>">'
  let s:testcase = '  <testcase classname="<testcase>" name="<test>" time="<time>"'
" }}}

" AssertEquals(arg1, arg2, ...) {{{
" Compares the two arguments to determine if they are equal.
function! vunit#AssertEquals(arg1, arg2, ...)
  if a:arg1 != a:arg2
    let message = '"' . string(a:arg1) . '" != "' . string(a:arg2) . '"'
    if a:0 > 0
      let message = a:1 . ' (' . message . ')'
    endif
    throw 'AssertEquals: ' . message
  endif
endfunction " }}}

" AssertNotEquals(arg1, arg2, ...) {{{
" Compares the two arguments to determine if they are equal.
function! vunit#AssertNotEquals(arg1, arg2, ...)
  if a:arg1 == a:arg2
    let message = '"' . string(a:arg1) . '" == "' . string(a:arg2) . '"'
    if a:0 > 0
      let message = a:1 . ' (' . message . ')'
    endif
    throw 'AssertNotEquals: ' . message
  endif
endfunction " }}}

" AssertTrue(arg1, ...) {{{
" Determines if the supplied argument is true.
function! vunit#AssertTrue(arg1, ...)
  if !a:arg1
    let message = '"' . a:arg1 . '" is not true.'
    if a:0 > 0
      let message = a:1 . ' (' . message . ')'
    endif
    throw 'AssertTrue: ' . message
  endif
endfunction " }}}

" AssertFalse(arg1, ...) {{{
" Determines if the supplied argument is false.
function! vunit#AssertFalse(arg1, ...)
  if a:arg1 || type(a:arg1) != 0
    let message = '"' . a:arg1 . '" is not false.'
    if a:0 > 0
      let message = a:1 . ' (' . message . ')'
    endif
    throw 'AssertFalse: ' . message
  endif
endfunction " }}}

" Fail(...) {{{
" Fails the current test.
function! vunit#Fail(...)
  let message = a:0 > 0 ? a:1 : ''
  throw 'Fail: ' . message
endfunction " }}}

" TestRunner(basedir, testfile, ...) {{{
" Runs the supplied test case.
" basedir - The base directory where the file is located.  Used to construct
"           the output file (testfile with basedir stripped off).
" testfile - The basedir relative test file to run.
if !exists('*vunit#TestRunner')
function! vunit#TestRunner(basedir, testfile)
  call s:Init(a:basedir, a:testfile)

  let tests = s:GetTestFunctionNames()
  let testcase = fnamemodify(a:testfile, ':r')

  call vunit#PushRedir('=>> g:vu_sysout')
  exec 'source ' . s:VUnitTestFile

  if exists('*BeforeTestCase')
    call BeforeTestCase()
  endif

  let now = localtime()
  for test in tests
    call s:RunTest(testcase, test)
  endfor

  if exists('*AfterTestCase')
    call AfterTestCase()
  endif

  call vunit#PopRedir()

  let duration = localtime() - now
  call s:WriteResults(a:testfile, duration)

  echom printf(
    \ 'Tests run: %s, Failures: %s, Time elapsed %s sec',
    \ s:tests_run, s:tests_failed, duration)

  if s:tests_failed > 0
    echom "Test " . a:testfile . " FAILED"
  endif
endfunction
endif " }}}

" PushRedir(redir) {{{
function! vunit#PushRedir(redir)
  exec 'redir ' . a:redir
  call add(s:redir_stack, a:redir)
endfunction " }}}

" PopRedir() {{{
function! vunit#PopRedir()
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

" PeekRedir() {{{
function! vunit#PeekRedir()
  call vunit#PushRedir(s:redir_stack[len(s:redir_stack) - 1])
  call vunit#PopRedir()
  return s:redir_stack[len(s:redir_stack) - 1]
endfunction " }}}

" s:Init(basedir, testfile) {{{
function! s:Init(basedir, testfile)
  let s:tests_cwd = getcwd()
  let s:tests_run = 0
  let s:tests_failed = 0
  let s:suite_methods = []
  let s:test_results = []
  let s:redir_stack = []
  let g:vu_sysout = ''

  unlet! s:VUnitOutputFile
  unlet! s:VUnitOutputDir

  silent! delfunction BeforeTestCase
  silent! delfunction SetUp
  silent! delfunction TearDown
  silent! delfunction AfterTestCase

  let s:VUnitTestFile = fnamemodify(a:basedir . '/' . a:testfile, ':p')

  if !exists('s:VUnitOutputDir')
    let g:VUnitOutputDir = expand(g:VUnitOutputDir)
    let s:VUnitOutputDir = g:VUnitOutputDir

    " check if directory exists, if not try to create it.
    if !isdirectory(g:VUnitOutputDir)
      " FIXME: fix to create parent directories as necessary
      call mkdir(g:VUnitOutputDir)
      if !isdirectory(g:VUnitOutputDir)
        echoe "Directory '" . g:VUnitOutputDir .
          \ "' does not exist and could not be created. " .
          \ "All output will be written to the screen."
        let s:VUnitOutputDir = ''
        return
      endif
    endif

    " construct output file to use.
    if !exists('s:VUnitOutputFile')
      let file = a:testfile

      " remove file extension
      let file = fnamemodify(file, ':r')
      " remove spaces, leading path separator, and drive letter
      let file = substitute(file, '\(\s\|^[a-zA-Z]:/\|^/\)', '', 'g')
      " substitute all path separators with '.'
      let file = substitute(file, '\(/\|\\\)', '.', 'g')

      let s:VUnitOutputFile = s:VUnitOutputDir . '/TEST-' . file . '.xml'

      " write output to the file
      call delete(s:VUnitOutputFile)
    endif
  endif
endfunction " }}}

" s:RunTest(testcase, test) {{{
function! s:RunTest(testcase, test)
  let now = localtime()
  if exists('*SetUp')
    call SetUp()
  endif

  let fail = []
  try
    call {a:test}()
    let s:tests_run += 1

    if exists('*TearDown')
      call TearDown()
    endif
  catch
    let s:tests_run += 1
    let s:tests_failed += 1
    call add(fail, v:exception)
    call add(fail, v:throwpoint)
  endtry

  let time = localtime() - now
  let result = {'testcase': a:testcase, 'test': a:test, 'time': time, 'fail': fail}
  call add(s:test_results, result)
  call s:TearDown()
endfunction " }}}

" s:TearDown() {{{
function! s:TearDown()
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

" s:GetTestFunctionNames() " {{{
function! s:GetTestFunctionNames()
  let winreset = winrestcmd()
  let results = []
  try
    new
    silent exec 'view ' . s:VUnitTestFile

    call cursor(1, 1)

    while search(s:function_regex, 'cW')
      let name = substitute(getline('.'), s:function_regex, '\1', '')
      if name == 'Suite'
        call Suite()
        return s:suite_methods
      endif

      if name =~ '^Test'
        call add(results, name)
      endif
      call cursor(line('.') + 1, 1)
    endwhile

  finally
    bdelete!
    exec winreset
  endtry
  return results
endfunction " }}}

" s:WriteResults(testfile, running_time) {{{
function! s:WriteResults(testfile, running_time)
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

    let testcase .= len(result.fail) == 0 ? '/>' : '>'

    call insert(results, testcase, index)

    if len(result.fail) > 0
      let message = substitute(result.fail[0], '"', '\&quot;', 'g')
      call insert(results, '    <failure message="' . message . '"><![CDATA[', index)
      let lines = split(result.fail[1], '\n')
      call map(lines, '"      " . v:val')
      for line in lines
        call insert(results, line, index)
      endfor
      call insert(results, '    ]]></failure>', index)
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

  call writefile(results, s:VUnitOutputFile)
endfunction " }}}

let &cpo = s:save_cpo

" vim:ft=vim:fdm=marker
