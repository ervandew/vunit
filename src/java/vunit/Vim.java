/**
 * Copyright (c) 2010, Eric Van Dewoestine
 * All rights reserved.
 *
 * Redistribution and use of this software in source and binary forms, with
 * or without modification, are permitted provided that the following
 * conditions are met:
 *
 * * Redistributions of source code must retain the above
 *   copyright notice, this list of conditions and the
 *   following disclaimer.
 *
 * * Redistributions in binary form must reproduce the above
 *   copyright notice, this list of conditions and the
 *   following disclaimer in the documentation and/or other
 *   materials provided with the distribution.
 *
 * * Neither the name of Eric Van Dewoestine nor the names of its
 *   contributors may be used to endorse or promote products derived from
 *   this software without specific prior written permission of
 *   Eric Van Dewoestine.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
 * IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
package vunit;

import java.io.ByteArrayOutputStream;
import java.io.IOException;

import java.util.ArrayList;
import java.util.List;

import org.apache.tools.ant.Project;

import org.apache.tools.ant.taskdefs.StreamPumper;

import org.apache.tools.ant.taskdefs.condition.Os;

import org.apache.tools.ant.types.Environment;
import org.apache.tools.ant.types.Path;

/**
 * Executes an external vim process.
 *
 * @author Eric Van Dewoestine
 */
public class Vim
  implements Runnable
{
  private int returnCode = -1;
  private List<Environment.Variable> properties;
  private List<Path> paths;
  private List<Plugin> plugins;
  private ArrayList<String> preCommands = new ArrayList<String>();
  private ArrayList<String> commands = new ArrayList<String>();
  private String result;
  private String error;
  private Process process;

  /**
   * Set a List of vim variables to be set when starting vim.
   *
   * @param properties List of ant Environment.Variable.
   */
  public void setProperties(List<Environment.Variable> properties)
  {
    this.properties = properties;
  }

  /**
   * Set a List of paths to be added to vim's runtimepath.
   *
   * @param plugins List of paths.
   */
  public void setPaths(List<Path> paths)
  {
    this.paths = paths;
  }

  /**
   * Set a List of vim plugins to be loaded.
   *
   * @param plugins List of plugin names.
   */
  public void setPlugins(List<Plugin> plugins)
  {
    this.plugins = plugins;
  }

  /**
   * Add a vim command to run prior to sourcing any vim files.
   *
   * @param cmd The vim command.
   */
  public void addPreCommand(String cmd)
  {
    this.preCommands.add(cmd);
  }

  /**
   * Add a vim command to run.
   *
   * @param cmd The vim command.
   */
  public void addCommand(String cmd)
  {
    this.commands.add(cmd);
  }

  /**
   * Execute the vim process.
   */
  public void execute()
    throws Exception
  {
    Thread thread = new Thread(this);
    thread.start();
    thread.join();
  }

  /**
   * Run the thread.
   */
  public void run()
  {
    try{
      Runtime runtime = Runtime.getRuntime();
      process = runtime.exec(buildCommand());

      final ByteArrayOutputStream out = new ByteArrayOutputStream();
      final ByteArrayOutputStream err = new ByteArrayOutputStream();

      Thread outThread = new Thread(new StreamPumper(process.getInputStream(), out));
      outThread.start();

      Thread errThread = new Thread(new StreamPumper(process.getErrorStream(), err));
      errThread.start();

      returnCode = process.waitFor();
      outThread.join(1000);
      errThread.join(1000);

      result = out.toString();
      error = err.toString();
    }catch(Exception e){
      returnCode = 12;
      error = e.getMessage();
      e.printStackTrace();
    }
  }

  /**
   * Destroy this process.
   */
  public void destroy()
  {
    if(process != null){
      process.destroy();
    }
  }

  /**
   * Gets the output of the command.
   *
   * @return The command result.
   */
  public String getResult()
  {
    return result;
  }

  /**
   * Get the return code from the process.
   *
   * @return The return code.
   */
  public int getReturnCode()
  {
    return returnCode;
  }

  /**
   * Gets the error message from the command if there was one.
   *
   * @return The possibly empty error message.
   */
  public String getErrorMessage()
  {
    return error;
  }

  String[] buildCommand(){
    StringBuffer vim = new StringBuffer("vim -u NONE -U NONE ");
    vim.append("--cmd \"set nocp | sy on | filetype plugin indent on\"");

    if (properties != null && properties.size() > 0){
      // build properties string.
      StringBuffer propertiesBuffer = new StringBuffer();
      for (Environment.Variable var : properties){
        if(propertiesBuffer.length() > 0){
          propertiesBuffer.append(" | ");
        }
        propertiesBuffer.append("let ")
          .append(var.getKey())
          .append("='")
          .append(var.getValue()).append("'");
      }
      vim.append(" --cmd \"" + propertiesBuffer + "\"");
    }

    // add runtimepath entries
    if (paths != null && paths.size() > 0){
      StringBuffer pathsBuffer = new StringBuffer();
      for (Path path : paths){
        if(pathsBuffer.length() > 0){
          pathsBuffer.append(',');
        }
        pathsBuffer.append(path);
      }
      vim.append(" --cmd \"set rtp+=" + pathsBuffer + "\"");
    }

    // add sourcing of plugins
    if (plugins != null && plugins.size() > 0){
      StringBuffer pluginsBuffer = new StringBuffer("runtime");
      for (Plugin plugin : plugins){
        pluginsBuffer.append(" " + plugin.getName());
      }
      vim.append(" --cmd \"" + pluginsBuffer + "\"");
    }

    // add any pre commands
    for (String preCmd : preCommands){
      vim.append(" --cmd \"" + preCmd + "\"");
    }

    // add vim commands
    for (String cmd : commands){
      vim.append(" -c \"" + cmd + "\"");
    }

    // ncurses + Runtime.exec don't play well together, so run via sh or cmd.
    String[] cmd = null;
    if (Os.isFamily(Os.FAMILY_WINDOWS)){
      vim.append(" -c \"qa!\"");
      cmd = new String[]{"cmd", "/c", vim.toString()};
    }else{
      vim.append(" -c 'qa!'");
      cmd = new String[]{"sh", "-c", vim + " &> /dev/null", "exit"};
    }
    return cmd;
  }
}
