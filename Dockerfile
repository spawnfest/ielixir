FROM hexpm/elixir:1.12.3-erlang-24.0.6-ubuntu-xenial-20210114

RUN apt-get update && apt-get install -y \
    software-properties-common git curl \
    && add-apt-repository ppa:deadsnakes/ppa \ 
    && apt-get update && apt-get install -y \
    python3.9 python3.9-distutils\ 
    && curl -sL https://deb.nodesource.com/setup_12.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/* \
    # && ln -s /usr/bin/python3.9 /usr/bin/python \
    && curl https://bootstrap.pypa.io/get-pip.py | python3.9


RUN python3.9 -m pip install jupyterlab

RUN jupyter labextension install jupyterlab-ielixir

RUN mix local.hex --force && mix local.rebar --force \
    && mix escript.install --force github spawnfest/ielixir \ 
    && ln -s /root/.mix/escripts/ielixir /usr/bin/ielixir

ARG time=0
    
RUN ielixir install

WORKDIR /workspace

RUN mkdir -p /root/.jupyter/ && touch /root/.jupyter/jupyter_lab_config.py \
    && printf "c.ServerApp.port = 8000\nc.ExtensionApp.open_browser = False\nc.ServerApp.ip = '0.0.0.0'\nc.ServerApp.open_browser = False\n" > /root/.jupyter/jupyter_lab_config.py

EXPOSE 8000

CMD [ "jupyter-lab", "--allow-root"]
