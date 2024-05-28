..  Copyright (c) 2005 - 2024, Eric Van Dewoestine
    All rights reserved.

    Redistribution and use of this software in source and binary forms, with
    or without modification, are permitted provided that the following
    conditions are met:

    * Redistributions of source code must retain the above
      copyright notice, this list of conditions and the
      following disclaimer.

    * Redistributions in binary form must reproduce the above
      copyright notice, this list of conditions and the
      following disclaimer in the documentation and/or other
      materials provided with the distribution.

    * Neither the name of Eric Van Dewoestine nor the names of its
      contributors may be used to endorse or promote products derived from
      this software without specific prior written permission of
      Eric Van Dewoestine.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
    IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
    THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
    PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
    CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
    EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
    PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
    PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
    LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
    NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
    SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

VUnit provides a JUnit / Python unittest like testing framework for vim scripts.

Here is an example test case that tests autoindent with tab expansion in a vim
file:

  ::

    function SetUp()
      set expandtab shiftwidth=2 tabstop=2
    endfunction

    function TestTabExpand()
      set ft=vim
      call append(0, ['if 1', 'endif'])
      call cursor(1, 1)
      normal oecho 'test'
      call vunit#AssertEquals(getline(2), "  echo 'test'")
    endfunction

Test can be run via:

#. Using the :VUnit vim command
#. Using the vunit python script
#. Using the ant task

For full details please see the provided `vim help doc`_.

.. _vim help doc: https://github.com/ervandew/vunit/blob/main/doc/vunit.txt
