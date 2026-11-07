# Notes

Hand-written entries for things Wikipedia leaves out or gets wrong, starting with
Indigenous foodways. Each note is a Markdown file with frontmatter and `[[wikilinks]]`,
the same format Obsidian uses, so this folder can be opened as a vault.

`scripts/merge_notes.py` merges them into the data on every rebuild (pushing a change
here runs the GitHub Action). Links resolve by name, alias or Wikipedia title across
cuisines, dishes and ingredients; the script lists any that don't.

## Cuisines (`content/cuisines/`)

```yaml
---
type: cuisine
name: Yup'ik cuisine
wikipedia: Yup'ik cuisine      # an entry on Wikipedia's list to add to; leave out for a new entry
indigenous: true
names: Yup'ik, Cup'ik          # the people's own names, shown under the title
area: Yukon-Kuskokwim Delta, Alaska
kind: peoples
iso3: USA                      # the country it shows under on the globe
loc: [61.0, -162.0]            # an approximate point, not a boundary
parent: "[[Native American cuisine]]"
aliases: [Yupik]
dishes: ["[[Akutaq]]"]
sources:
  - name: Alaska Native Tribal Health Consortium
    url: https://...
suggested:                     # research suggestions, shown as "Suggested"
  sites: [{name: ..., url: ..., note: ...}]
  cookbooks: [{title: ..., author: ..., year: 2000, isbn: "978...", url: ...}]
---
Short intro in our own words. Link dishes and ingredients like [[Akutaq]] or [[Seal oil]].
```

## Dishes and ingredients (`content/dishes/`, `content/ingredients/`)

```yaml
---
type: dish
name: Akutaq
aliases: [Eskimo ice cream]
wikipedia: Akutaq              # if Wikipedia has an article
cuisines: ["[[Yup'ik cuisine]]"]
ingredients: ["[[Seal oil]]", "[[Berries]]"]
---
```

Places are approximate points, never territory lines. These notes describe living
foodways in the present tense, and anyone can suggest a correction from the card.
