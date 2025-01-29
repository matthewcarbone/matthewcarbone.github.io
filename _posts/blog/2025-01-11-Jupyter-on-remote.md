---
layout: post
title: "Running Jupyter as a service on a remote workstation: a practitioner's guide"
date: 2025-01-11
categories: Code
bnl_disclaimer: true
---
Consider the following use case: you have a powerful workstation at your job or another location, and all you have available is your significantly less powerful laptop and an internet connection. You love using [Jupyter Notebooks](https://jupyter.org/)/Lab, and would like to use the resources of your workstation, from your laptop. How do you make this happen in a robust, stable way?

In this post, I will attempt to detail how to do exactly this.

A quick note: this post will make a lot more sense if you're familiar with SSH. Specifically, I recommend reviewing at least [SSH keys](https://www.ssh.com/academy/ssh-keys).

# Jupyter as a service
When you launch a Jupyter Notebook/Lab, you are really just creating a process on your computer that talks to other applications over [http](https://en.wikipedia.org/wiki/HTTP). For instance, say you simply run:
```bash
# if your environment is already loaded
jupyter-lab

# or, via something like uv
uvx --from=jupyterlab jupyter-lab
```
You should see a bunch of output to your terminal, and that output should include something like this:
```
[I ... ServerApp] Jupyter Server 2.15.0 is running at:
[I ... ServerApp] http://localhost:8889/lab?token=...
[I ... ServerApp]     http://127.0.0.1:8889/lab?token=...
```
Jupyter is telling you that you're running a Jupyter _server_ on `localhost` (your local machine), and that server is listening for traffic on port 8889. 

Now, by default, Jupyter opens up your browser so you don't have to think twice about it, but to demonstrate the point, add the `--no-browser` flag to your command:
```bash
# if your environment is already loaded
jupyter-lab --no-browser

# or, via something like uv
uvx --from=jupyterlab jupyter-lab --no-browser
```
Now, no browser opens right away, but you should still see information about the service that has started. You should also see a few lines that look something like this:
```
[C 2025-01-10 06:56:06.805 ServerApp]

    To access the server, open this file in a browser:
        .../Library/Jupyter/runtime/jpserver-50333-open.html
    Or copy and paste one of these URLs:
        http://localhost:8889/lab?token=...
        http://127.0.0.1:8889/lab?token=...
```
Essentially, Jupyter is telling you how to "talk" to the service you just started. Try copying/pasting that url (including the token) into your favorite web browser and see what happens.

The most important takeaway here is that when you add code to the notebooks in your browser, run code, save code, etc., all that is happening is you are sending information to the Jupyter service (in this case, running on your own computer) and it's sending information back to you. That's it. There is no reason, however, that this service has to be running on your laptop.

# SSH tunneling
It is possible to set up an SSH tunnel in which any traffic that occurs on some port on your local machine is "forwarded" over SSH, to a remote machine (and similarly, any traffic that is posted on some remote port can be forwarded back to you). This SSH tunnel is what will allow us to run a Jupyter service on a remote machine, but connect to it on your local laptop.

Before diving into the details of how to create an SSH tunnel, make sure you have your `~/.ssh/config` file [setup correctly](https://linuxize.com/post/using-the-ssh-config-file/) and have [copied your ssh key to your workstation](https://www.ssh.com/academy/ssh/copy-id). 

Let's say, I have a computer named `workstation` on my job's local network. I may have setup a `~/.ssh/config` that looks something like this:
```
Host workstation
    HostName my_worstation_name.xxx.yyy.zzz
    User mcarbone
    IdentityFile ~/.ssh/id_rsa_123
```
such that I can connect to my workstation via `ssh workstation`.

We can go one step further, and forward all communication between a specific port on my local laptop and my workstation by setting up an SSH tunnel, or "port forwarding" via the straightforward command:
```bash
ssh -L 8899:localhost:8888 -N workstation
```
This does the following: all traffic on laptop port 8899 is forwarded to port 8888 on the workstation. As such, this means that if we have a Jupyter service running on the workstation and listening on port 8888, we should be able to connect to it on the laptop, talking to port 8899.

# Keeping the connection alive
If you close your laptop, disconnect from the internet, or the connection times out (all of these happen to me often), you will lose the tunnel, Jupyter will stop working, and your console will indicate a "broken pipe," or something along those lines.

To prevent this from happening, I recommend using some form of process manager to ensure that if the connection does go down, it is monitored and restarted automatically. My current tool of choice is [pm2](https://pm2.keymetrics.io/docs/usage/quick-start/), though there are more out there. What's especially nice about these types of tools is that they allow you to start any process, and monitor it separately from your system's other processes. Definitely check out the documentation to get a better feeling of how to use it. For now, the rest can be demonstrated by example.

# A complete example

## Step 1: run Jupyter Lab on your workstation
From your laptop, connect to your remote machine. Then, start a Jupyter server. As mentioned above, I like using pm2 to keep the connection alive and keep track of the services I start manually.
```bash
pm2 start "uvx --from=jupyterlab jupyter-lab --no-browser --port 8888" \
	--name jupyter-8888
```
Note that port 8888 should not already be in use, and you are of course free to choose whichever port you'd like. I have also named this service such that it's easy to access later on (e.g., I can show the logs for this service by running `pm2 logs jupyter-8888`).

If you started this service with pm2, you can now safely exit your remote machine. The service will continue running in the background, and should automatically restart if it's interrupted.

## Step 2: open an SSH tunnel from your laptop
On your laptop, we now need to open an SSH tunnel that connects a port of your choosing to the remote machine's localhost port 8898. Once again, I use pm2 to automatically restart the tunnel if there are any interruption.
```bash
pm2 start "ssh -L 8899:localhost:8888 -N workstation" \
	--name tunnel-8899-8888
```

## Step 3: open Jupyter from your laptop web browser
Finally, the last and easiest step is to connect to `localhost:8899` on your web browser. You may have to enter the authentication token from the original service on your workstation (check the logs). You should now have a stable way of using a remote system's resources from the convenience of your laptop!

Note, you can stop or delete any service you're running with pm2 via e.g. `pm2 stop PROCESS_NUMBER_OR_NAME`. Review the docs for more information!

# Conclusions
In this post, we have gone over how SSH tunneling works and how it can be used to interface with a Jupyter server running on a remote workstation, all from your laptop. As long as it is possible to open an SSH connection with the remote host, you can use SSH tunneling to "talk" to a service running there. 

It should be noted that there is nothing unique or special about Jupyter here. Any service that is listening on some port can be "talked to" via this protocol.