# scripts
Scripts for boring tasks

Here's a list of small scripts that have been making my life a lot easier. I also learned to love [PowerShell](https://docs.microsoft.com/en-us/powershell/scripting/overview?view=powershell-6) in the process. If you're not familiar with PowerShell yet this might be a good starting point.

In my dev box I happen to have a lot of [GeneXus](https://www.genexus.com) Knowledge Bases, which impacts in the amount of Databases my local SQL Server has and the amount of web apps on both IIS and Apache Tomcat.

Every bat file here is in a directory which is in my PATH environment variable, that bat calls the real deal maker which is a PowerShell script with the same name under the folder [ps](./ps).

### clean_docker  
Goes thru all your [dangling images](https://stackoverflow.com/questions/45142528/docker-what-is-a-dangling-image-and-what-is-an-unused-image) and removes them .

### clean_iis
Goes thru all your IIS 'Default Web Site' web applications, and checks if the physical path it is aiming exists in your drive. If it does not, it removes the web app.

### clean_kb
It can receive either the path to a GeneXus [Knowledge Base](https://wiki.genexus.com/commwiki/servlet/wiki?1836,Knowledge%20Base) or the path to a folder where many 'junk' Knowledge Bases exist. For every Knowledge Base it'll try to remove the SQL Server database and then remove the whole folder.

##### if you pass a folder containing Knwoledge Bases, the -batch parameter must be set. Be careful!

### clean_tomcat
This one mightnot work for everybody. But in my local [Apache Tomcat](https://tomcat.apache.org/) I only have disposable test apps, every once in a while they tend to pile up so this script goes thru all the web apps and removes them, with the exception of some well-known folders.
