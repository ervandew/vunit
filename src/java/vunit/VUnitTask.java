/**
 * Copyright (c) 2005 - 2010, Eric Van Dewoestine
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

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;

import java.util.ArrayList;
import java.util.Arrays;

import javax.xml.parsers.SAXParser;
import javax.xml.parsers.SAXParserFactory;

import org.apache.tools.ant.BuildException;
import org.apache.tools.ant.DirectoryScanner;
import org.apache.tools.ant.Project;
import org.apache.tools.ant.Task;

import org.apache.tools.ant.taskdefs.condition.Os;

import org.apache.tools.ant.types.Environment;
import org.apache.tools.ant.types.FileSet;
import org.apache.tools.ant.types.Path;

import org.apache.tools.ant.util.FileUtils;

import org.xml.sax.Attributes;
import org.xml.sax.SAXException;

import org.xml.sax.helpers.DefaultHandler;

/**
 * Ant task for executing vunit test cases.
 * <p/>
 * Currently only intended for unix based systems.
 *
 * @author Eric Van Dewoestine
 */
public class VUnitTask
  extends Task
{
  private static final String TESTSUITE = "testsuite";
  private static final String TESTCASE =
    "silent! call vunit#TestRunner('<basedir>', '<testcase>')";

  private File todir;
  private ArrayList<Plugin> plugins = new ArrayList<Plugin>();
  private ArrayList<Path> paths = new ArrayList<Path>();
  private ArrayList<FileSet> filesets = new ArrayList<FileSet>();
  private ArrayList<Environment.Variable> properties =
    new ArrayList<Environment.Variable>();
  private String failureProperty;
  private boolean haltOnFailure;
  private boolean failed;

  /**
   * Executes this task.
   */
  public void execute()
    throws BuildException
  {
    validateAttributes();

    try{
      SAXParser parser = SAXParserFactory.newInstance().newSAXParser();
      DefaultHandler handler = new ResultHandler();

      String vunit = extractVUnitPlugin().getAbsolutePath().replace('\\', '/');

      for (FileSet set : filesets){
        DirectoryScanner scanner = set.getDirectoryScanner(getProject());
        File basedir = scanner.getBasedir();
        String[] files = scanner.getIncludedFiles();

        String run = TESTCASE.replaceFirst(
            "<basedir>", basedir.getAbsolutePath().replace('\\', '/'));

        for (String file : files){
          file = file.replace('\\', '/');
          log("Running: " + file);

          Vim vim = new Vim();
          vim.setProperties(properties);
          vim.setPaths(paths);
          vim.setPlugins(plugins);
          vim.addCommand("source " + vunit);
          vim.addCommand(run.replaceFirst("<testcase>", file));

          log("vunit: " + Arrays.toString(vim.buildCommand()), Project.MSG_DEBUG);

          vim.execute();
          if(vim.getResult().trim().length() > 0){
            log(vim.getResult().trim());
          }

          if(vim.getReturnCode() != 0){
            throw new BuildException(
                "Failed to run command: " + vim.getErrorMessage());
          }

          String path = file.replaceFirst("(.*/).*", "$1");
          if (path.equals(file)){
            path = "";
          }
          String name = file.replaceFirst(".*/(.*)", "$1");
          name = name.replaceFirst("([^/]*?)\\..*$", "$1");
          StringBuffer resultFileName = new StringBuffer()
            .append(todir.getAbsolutePath())
            .append(File.separator)
            .append("TEST-")
            .append(path.replace('/', '.'))
            .append(name)
            .append(".xml");
          File resultFile = new File(resultFileName.toString());

          try{
            parser.parse(resultFile, handler);
          }catch(SAXException se){
            if(!TESTSUITE.equals(se.getMessage())){
              throw se;
            }
          }

          if(failed){
            if (failureProperty != null &&
                getProject().getProperty(failureProperty) == null){
              getProject().setNewProperty(failureProperty, "true");
            }

            if(haltOnFailure){
              throw new BuildException("Test failed: " + file);
            }
          }
        }
      }
    }catch(BuildException be){
      throw be;
    }catch(Exception e){
      throw new BuildException(e);
    }
  }

  /**
   * Validates the supplied attributes.
   */
  private void validateAttributes()
    throws BuildException
  {
    if(todir == null){
      throw new BuildException("Attribute 'todir' required");
    }

    if(!todir.exists() || !todir.isDirectory()){
      throw new BuildException(
          "Supplied 'todir' is not a directory or does not exist.");
    }

    if(filesets.size() == 0){
      throw new BuildException(
          "You must supply at least one fileset of test files to execute.");
    }
  }

  private File extractVUnitPlugin()
    throws Exception
  {
    InputStream in = this.getClass().getResourceAsStream("/vunit.vim");
    if(in == null){
      throw new BuildException("Unable to locate vunit.vim resource.");
    }
    File temp = new File(
        System.getProperty("java.io.tmpdir") + File.separator + "vunit.vim");
    temp.deleteOnExit();
    FileOutputStream out = new FileOutputStream(temp);

    try{
      byte[] buffer = new byte[1024 * 4];
      int n = 0;
      while (-1 != (n = in.read(buffer))) {
        out.write(buffer, 0, n);
      }
    }finally{
      FileUtils.close(in);
      FileUtils.close(out);
    }
    return temp;
  }

  /**
   * Adds a plugin to be loaded prior to running the tests.
   * @param plugin The plugin.
   */
  public void addPlugin(Plugin plugin)
  {
    plugins.add(plugin);
  }

  /**
   * Adds a path to be included in the vim runtimepath when running tests.
   * @param set A path element.
   */
  public void addPathelement(Path path)
  {
    paths.add(path);
  }

  /**
   * Adds a set of test files to execute.
   * @param set Set of test files.
   */
  public void addFileset(FileSet set)
  {
    filesets.add(set);
  }

  /**
   * Adds a property to be set when running the tests.
   * @param prop The property.
   */
  public void addSysproperty(Environment.Variable prop)
  {
    properties.add(prop);
  }

  /**
   * Sets the todir for this instance.
   *
   * @param todir The todir.
   */
  public void setTodir(File todir)
  {
    this.todir = todir;
    Environment.Variable var = new Environment.Variable();
    var.setKey("g:VUnitOutputDir");
    var.setValue(todir.getAbsolutePath().replace('\\', '/'));
    addSysproperty(var);
  }

  /**
   * Sets the name of the property to be set if a failure occurs.
   *
   * @param failureProperty The failureProperty.
   */
  public void setFailureproperty(String failureProperty)
  {
    this.failureProperty = failureProperty;
  }

  /**
   * Sets whether or not to halt on failure.
   *
   * @param haltOnFailure The haltOnFailure.
   */
  public void setHaltonfailure(boolean haltOnFailure)
  {
    this.haltOnFailure = haltOnFailure;
  }

  /**
   * SAX handler for vunit result parsing.
   */
  private class ResultHandler
    extends DefaultHandler
  {
    /**
     * {@inheritDoc}
     * @see org.xml.sax.helpers.DefaultHandler#startElement(String,String,String,Attributes)
     */
    public void startElement(
        String uri, String localName, String qName, Attributes atts)
      throws SAXException
    {
      int tests = Integer.parseInt(atts.getValue("tests"));
      int failures = Integer.parseInt(atts.getValue("failures"));
      String time = atts.getValue("time");
      String name = atts.getValue("name");

      StringBuffer buffer = new StringBuffer()
        .append("Tests run: ").append(tests)
        .append(", Failures: ").append(failures)
        .append(", Time elapsed: ").append(time).append(" sec");
      log(buffer.toString());

      if(failures > 0){
        log("Test " + name + " FAILED");
        failed = true;
      }

      throw new SAXException(TESTSUITE);
    }
  }
}
