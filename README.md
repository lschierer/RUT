This project assumes you have installed and configured [mise](https://mise.jdx.dev/).  If you have, it should automatically warn you if you do not have the required versions of [node](https://nodejs.org/), [pnpm](https://pnpm.io/), and other build tools the project depends on.  Any exceptions will be noted here.

Assuming that you *do* have mise, and it has *not* complained, you can simply run

```
mise run dev
```

to get a local development version of the project.

## Exceptions:

* This project assumes that you have the GNU version of sed, in your path, as ```gsed```.  This is typical on Mac OSX systems, and probably nowhere else, but trivial to achieve with aliases on any unix where this is not true.
* the bsd version of the head command on OSX also differs from the GNU version, so again I use the GNU ```ghead```  and ```gtail``` commands.
* mise cannot install [jq] for you.
* mise cannot some c libraries:
  * libgit2
  * libssh2
* mise cannot install [GNU parallel] for you.  This is needed for the check tasks.
* mise cannot install [pandoc]
* mise cannot install [discount]


[linkchecker]: https://linkchecker.github.io/linkchecker/
[GNU parallel]: https://www.gnu.org/software/parallel/
[jq]: https://jqlang.github.io/jq/
[pandoc]: https://pandoc.org/
[discount]: https://github.com/Orc/discount