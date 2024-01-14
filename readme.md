# Interstellar

Interstellar is a linux server setup that uses docker-compose to run a number of services connected to an internal and external reverse proxy to bypass CGNAT. To Run the project, you will need:

- Domain
- Cloudflare Account
- SMTP Account (for example, gmail)
- Machine with public IP address
- Your own machine for all the services

## Environment Variables

Rename every `*.env.example` file to `*.env` and fill in the variables and fill in the variables.

## Setup

Just run the `install.sh` script in the root of the project. This will install all the services and setup the reverse proxy.
If you just want to install a specific feature, you can just run apropiate script in folders `DMZ`, `VPS` or `General`.
