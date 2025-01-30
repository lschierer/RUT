import commits from "../lib/commitHistory.ts";
import { DateTime, Duration } from "luxon";

import { getContentByRoute } from "@greenwood/cli/src/data/client.js";

import { Page } from "../lib/greenwoodPages.ts";

import debugFunction from "../lib/debug.ts";
const DEBUG = debugFunction("src/components/RecentChanges.ts");

type Entry {
  id: string,
  delta: Duration,
  pages: Page[],
  message: string,
}

export default class RecentChanges extends HTMLElement {
  async connectedCallback() {
    const now = DateTime.now();

    const entries = new Array<Entry>()

    for (const commit of commits) {

      const date = DateTime.fromSeconds(+commit.date);
      const diff = now.diff(date);
      const delta = diff.shiftToAll();
      const pages = new Array<Page>();
      let count = 0;

      if(DEBUG) {
        console.log(`for ${commit.id} starting count at ${count}`)
      }
      for (const file of commit.files) {
        if (count > 100) {
          if(DEBUG) {
            console.log(`already found 100 pages for ${commit.id}. breaking to preserve resources`)
          }
          break;
        }
        let r = `${file.replace(/^(\s)*/, '').replace(/^packages\/luke\//, '').replace(/.md(wn)?(\s)?$/, "")}/`
        if(!r.startsWith('/')) {
          r = `/${r}`;
        } else {
          if(DEBUG) {
            console.log(`r passed first check with route ${r}`)
          }
        }
        if(!r.startsWith('/luke')) {
          r = `/luke${r}`
        } else {
          if(DEBUG) {
            console.log(`r passed 2nd check with route ${r}`)
          }
        }
        if (!r.startsWith('/luke/log')) {
          r = r.replace(/^\/luke/, "/luke/log")
        } else {
          if (DEBUG) {
            console.log(`r passed 3rd check with route ${r}`)
          }
        }
        if (DEBUG) {
          console.log(`finding pages for file '${file}' with route '${r}'`);
        }

        const p = (await getContentByRoute(r));
        if (p) {
          if(DEBUG) {
            console.log(`p is ${Array.isArray(p)} with length ${p.length}`)
          }
          if(Array.isArray(p) && p.length > 0) {
            pages.push(p[0]);
            count++;
          }
        }
      }
      if(DEBUG) {
        console.log(`pushing entry with id ${commit.id} with ${pages.length} pages`)
      }
      entries.push({
        id: commit.id,
        delta,
        pages,
        message: commit.message.join('\n')
      })
    }
    if (commits && Array.isArray(commits) && commits.length > 0) {
      this.innerHTML = `
        <dl class="RecentChanges">
          ${entries.sort((a,b) => {
            const as = a.delta.as('seconds')
            const bs = b.delta.as('seconds')
            if(as == bs) {
              return 0;
            } else if (as < bs ) {
              return -1
            } else {
              return 1;
            }
          }).map((entry) => {
            const pages = entry.pages.length > 10 ? entry.pages.slice(0, 10) : entry.pages;
            return `
              <dt>
                <a href="https://github.com/lschierer/RUT/commit/${entry.id}">${entry.id.slice(0, 12)}</a></dt>
              <dl>${entry.pages.length > 0 ? `<span class="definitionHeading">Changed Pages:</span>` : entry.message}
                <ul>
                  ${pages.map((p) => {
                    return `
                      <li>
                        <a href="${p.route}" >${p.title ? p.title : p.label}</a>
                      </li>
                    `
                  }).join('\n')}
                  ${entry.pages.length > 10 ? `
                  <li> ... and ${entry.pages.length - 10 } more files </li>
                  ` : ""}
                </ul>
              </dl>
              <dl>
                ${
                  entry.delta.years
                    ? entry.delta.years > 1
                      ? `${entry.delta.years} years`
                      : `${entry.delta.years} year`
                    : ""
                }
                ${
                  entry.delta.months
                    ? entry.delta.months > 1
                        ? `${entry.delta.months} months`
                        : `${entry.delta.months} month`
                      : ""
                  }
                  ${
                    entry.delta.weeks
                      ? entry.delta.weeks > 1
                        ? `${entry.delta.weeks} weeks`
                        : `${entry.delta.weeks} week`
                      : ""
                  }
                  ${
                    entry.delta.days
                      ? entry.delta.days > 1
                        ? `${entry.delta.days} days`
                        : `${entry.delta.days} day`
                      : ""
                  }
                  ${
                    entry.delta.hours
                      ? entry.delta.hours > 1
                        ? `${entry.delta.hours} hours`
                        : `${entry.delta.hours} hour`
                      : ""
                  }
                  ${
                    entry.delta.minutes
                      ? entry.delta.minutes > 1
                        ? `${entry.delta.minutes} minutes`
                        : `${entry.delta.minutes} minute`
                      : ""
                  }
                  ago
                </dl>
          `;
        }).join("\n") }
        </dl>
      `;
    }
  }
}
customElements.define("recent-changes", RecentChanges);
