## Installation

```
jupyter labextension install jupyterlab-ielixir
```

## Development

For a development install (requires npm version 4 or later), do the following in the repository directory:

```
npm install
npm run build
jupyter labextension link .
```

To rebuild the package and the JupyterLab app:

```
npm run build
jupyter lab build
```
