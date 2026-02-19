# Schierer.org web server project

This project will create a web server for https://www.schierer.org that can also be accessed using https://schierer.org 
It should be able to stand up a test stack at https://www.${MODE}.schierer.org that can also be accessed at https://${MODE}.schierer.org where $MODE is passed to cdk via environment variable. 


There are two aspects of this project. 

1. under packages/archives are a series of tarballs
	 * Each of these represents the archived contents of one set of files that was the public_html folder for one user.  
	 * Most of them contain largely static html and image files.  We should be able to display these static html and image files at https://www.schierer.org/~username/* exactly as if we were still on a system that supported serving public_html folders for system users. 
	 * a few may contain php files.  We are not concerned with the fact that any php files in them will not display correctly. Users were warned. 
    * this could be handled with a combination of cdk deployment, post-deployment scripting on the ec2 instance, and nginx configuration. 
1. under /packages there are two additional users, 'luke' and 'ann' that require special handling. 
   1. the 'ann' user is fairly simply.  it is identical to the previous static file handling use case except that it also requires dynamic index pages.
   		* ~/ann/ and ~/ann/poems show identical content except that they have different relative paths to the pages they link to
   		* both show a dynamically generated index of the .html files in ann/poems
   		* the dynamic index should use css to dynamically arrange the list of poems into columns based on the width of the browser window. 
   	1. the 'luke' user is more complicated. 
   	  1. .txt, .pdf, .html files at `packages/luke/*` should be served at `~/luke/*` 
   	  1. files under `packages/luke/staticAssets/*` should be served at `~luke/*` 
   	  1. markdown with the .md extension under `packages/luke/**/*` should be processed with discount and rendered at `~/luke/**/*`
   	  1. markdown under `packages/luke/log/**/*.mdwn` _that does not conflict with a previous rule_ should be converted from ikiwiki to gfm markdown then handled under the previous rule. 
   	  1. markdown under `packages/luke/log/**/*` under *either* of the previous two rules should be displayed using a template that has a last edited date. the last edited field should
   	     1. default to git
   	     1. use the last edited information in the front matter if available and the extension is .md
   	     1. use the last edited information from the meta tags if available and the extension is .mdwn 
   	     1. should use DateTime::Format::Natural to display the last edited date as a relative time from now as in "n days ago" or "earlier today" or other vague user-friendly strings
1. there is a partially successful version of this project that used Perl 5.42, Mojolicious, and typescript at packages/frontend.  You can copy working bits out of that. 
1. There is some partially working code to convert from ikiwiki to gfm in packages/luke that can be reused. 
1. The final solution should use Ngnix, Perl 5.42 (or newer), and the common framework at ../PAGI-WebServer 
   * The common framework is built around
     * Perl 5.42 (or newer)
     * Perl [Thunderhorse](https://metacpan.org/pod/Thunderhorse)
     * Perl [PAGI](https://metacpan.org/pod/PAGI)
     * typescript 
     * CDK
   * The common framework requires a small cdk wrapper to deploy.  We will use this.  We will use the shared VPC stack already provisioned in US-EAST-2. 
   * There is very little truly dynamic content in this project.  Nearly everything *could* be done as a pre-deployment step *except* that the ~luke user has some ikiwiki redirects that will need to be handled with 308 redirects. 