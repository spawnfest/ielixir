# IElixir

Jupyter's kernel for Elixir

## Acknowledgements, licenses, and disclaimers

Implementation is inspired by [`IElixir`](https://github.com/pprzetacznik/IElixir), while all the codebase is totally rewritten to fit `escripts`, **Elixir**'s 1.12 `Mix.install/2` feature and kernel management introduced by [`livebook`](https://github.com/livebook-dev/livebook).

All the code for node management is fully taken from [`livebook`](https://github.com/livebook-dev/livebook)'s codebase.

This project is distributed under the `MIT` license, while node management parts are distributed under `Apache License 2.0`, inherited from [`livebook`](https://github.com/livebook-dev/livebook).

## Installation

You must have:

1. One of the `jupyter`'s installations
1. **Elixir** 1.12 or higher

### Jupyter notebook

To use this kernel, you need to have a `Jupyter` installed. You can find instructions on how to install it [here](https://jupyter.readthedocs.io/en/latest/install/notebook-classic.html).

The simplest way to do this is to run:

    $ pip install jupyter

Installing it with a virtual environment is recommended, but instructions to do it are out of this document's scope.

### Jupyter lab

This frontend is a modern approach to work with **Jupyter**'s kernels, supports more features, and is recommended for been used for most cases.
You can find instructions on how to install it [here](https://jupyterlab.readthedocs.io/en/stable/getting_started/installation.html).

The simplest way to do this is to run:

    $ pip install jupyterlab

This command will also install the original `jupyter notebook` under the hood.

### Elixir

You need to have **Elixir** installed. You can find instructions on how to install it [here](https://elixir-lang.org/install.html).
For sure you know how to do it if you are trying to use this project.

### IElixir kernel

Installation is pretty simple:

1. Install the escript for this kernel:
   
   ```bash
   $ mix escript.install github spawnfest/ielixir
   ```

1. Make the `jupyter` to _know_ our new kernel:

    ```bash
    $ ielixir install
    ```

1. (_Optional_) If you want to use the `jupyterlab` frontend, you need to additional `ielixir` lablexicon:

    ```bash
    $ jupyter labextension install jupyterlab-ielixir
    ```


And you are all set!

## Running with docker

1. Build the docker image using presented `Dockerfile`:
    
    ```bash
    docker build . -t ielixir
    ```

1. Run the image to get your server running on `8000` port:

    ```bash
    docker run -p 8000:8000 ielixir
    ```

1. In docker's output you will see a link with defined token. Use it to open your `Jupyter Lab` in the browser.

**NOTE!** Default workspace is empty! If you need to work with a workspace that exists on your host machine - 
you need to mount this folder inside containers `/workspace` folder.

```bash
docker run --mount type=bind,source=path/to/workspace/,target=/workspace -p 8000:8000 ielixir
```

For example, to run examples from project's root use:

```bash
docker run --mount type=bind,source="$(pwd)"/resources/examples,target=/workspace -p 8000:8000 ielixir
```


## Roadmap

- [x] `jupyter` messaging protocol
- [ ] `Elixir` node for each kernel
  - [x] Standalone
  - [ ] `mix project`
  - [ ] `remote`
- [x] Code highlighting for 
  - [x] input
  - [x] output
- [ ] History saving and exposing
- [ ] Compatibility with 
  - [x] `console`
  - [x] `notebook`
  - [x] `lab`
  - [ ] `vscode` extension
- [x] Providing protocol for output decoration
  - [x] Client side
  - [x] kernel side
- [x] Automaticly decorating
  - [x] pictures 
  - [x] vega plots
  - [x] jsons
- [ ] Autocompletion
  - [x] Intellisense
  - [ ] Perfect cursor positioning
- [ ] Example notebooks
  - [x] Intro to Jupyter
  - [ ] Intro to Elixir inside IElixir
  - [ ] Intro to Elixir
  - [x] Example from Elixir's official syte
