# Interstellar

Interstellar is a linux server setup that uses docker-compose to run a number of services connected to an internal and external reverse proxy to bypass CGNAT. To Run the project, you will need:

- Domain
- Cloudflare Account
- SMTP Account (for example, gmail)
- Machine with public IP address
- Your own machine for all the services


## Deployment
1. Rename every `*.env.example` file to `*.env` and fill in the variables and fill in the variables.
2. Setup apps, run `docker compose exec recyclarr sync`
3. Setup Traefik and CrowdSec
4. [Setup Authentik with Traefik](https://github.com/brokenscripts/authentik_traefik?tab=readme-ov-file)
5. [Create LDAP outpost](https://docs.goauthentik.io/docs/add-secure-apps/providers/ldap/) and [configure LDAP Authentik with Jellyfin](https://docs.goauthentik.io/integrations/services/jellyfin/) (remember to add network name to outpost config and use internal ports of Outpost in Jellyfin)
6. Profit
