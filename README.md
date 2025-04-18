# Lightweight SOAR System for Citrix NetScaler

Here's the complete Linkedin article that explain how it works:
https://www.linkedin.com/pulse/introducing-lightweight-soar-solution-citrix-n8nio-stefano-baronio-rjclf/

There are 5 n8n workflows that implement a lightweight SOAR solution for Citrix Netscaler. This laboratory example shows how to digital jail the offender IPs that overlimit the a rate-limiting policy implemented in the Netscaler.

For those unfamiliar, [n8n.io](https://n8n.partnerlinks.io/3uv6z7oipivj) is a leading open-source automation platform offering versatile solutions both on-premises and in the cloud.

## The Features 

- **Bulk configuration** of a set of Netscalers by putting their nsip in a Google Sheet.
- **Dynamic Attack Response**: Real-time modification of Netscaler configuration to block threats (don't panic, it's just adding and removing IPs in Datasets and managing Datasets, you are in charge of the policies).
- **Automatic Dataset Management**: Datasets for IP blocking are managed dynamically without manual intervention. It notifies you via email when new datasets are created (so you can add them to the policies). For the more adventurous, it's possible to develop a workflow that automatically modifies policies following the creation of a new dataset. Please note: datasets are only added, they won't be deleted automatically. Again, with a new workflow....
- **Scheduled IP Unblocking**: IP addresses blocked temporarily are cleared automatically after a configurable TTL (Time-To-Live).
- **Bidirectional Synchronization**: Engineers can manually modify blocked IPs directly on NetScaler, with automatic syncing back to the central database.
- **Google Sheets Configuration**: Centralized configuration management through Google Sheets simplifies updates and maintenance.

## Initial NetScaler Configuration

We're gonna use NetScaler's HTTP Callout feature to chat with the outside world (our n8n setup). 

We assume that n8n is put behind a reverse proxy (n8n.domain.com) that encrypts via SSL the connection on standard port 443. We will not explain the certs creation and installation here.

Before starting, ensure NetScaler devices have these basic configurations: 

- Add a Server with n8n FQDN (e.g. n8n.domain.com)
- Set the service and the vServer (n8n-svc.domain.com and n8n-lb.domain.com)
- HTTP Callout: Connect NetScaler with n8n workflows. The URL called depends on the n8n webhook workflow.
- Responder Policies: Detect and respond to threats like Rate Limiting, Failed Logins, etc.

NetScaler friendly CLI commands are at the end.

## Workflow Deep Dive

### 1. Initialization Workflow (Bulk Configuration)

This workflow gets the configuration data from a Google Sheet, though other data sources can also be integrated.

**Key Features:**

- Automatically sets essential configuration variables on NetScaler, ensuring consistency across deployments.
- Centralized management of TTL (Time To Live) values for blocked IPs, eliminating the need for manual updates directly on NetScaler and guaranteeing uniform policy enforcement.

**Example Configuration Data**

![Screenshot from 2025-04-09 16-15-27](https://github.com/user-attachments/assets/52144f60-adff-4b4e-be90-35c536ab2429)


**Important Notes:**

- Column headers are hard-coded into the workflows, you shouldn't touch them! However, you can customize variable names and dataset naming conventions to your preference.
- Datasets are automatically named by the workflow—for instance in this case, block_ip_list_1, block_ip_list_2, and so forth.
- The TTL for blocked IP addresses is specified in minutes.

**Security Considerations:**

- n8n includes an integrated mechanism for securely storing credentials in an encrypted database. This mechanism is used for Google Sheets, PostgreSQL, and NetScaler credentials.
- n8n Enterprise plan gives you access to remote secrets manager (eg. Hashicorp Vault), plus a number of other features.

In this scenario, it is assumed that a single NetScaler user, possessing adequate privileges to create Netscaler variables, datasets, and manage IP bindings, is configured and valid across all Netscaler instances listed in the Google Sheet. 

Netscaler CLI commands at the end of the article. 

Here's the clip of the Init workflow with its sparkling nodes (that's the best part of the whole system).


https://github.com/user-attachments/assets/9100132c-47d3-4c97-b58e-4762111bb8dd



### 2. Queue Workflow

**The First Line of Defense: Catching Those Troublemakers in Action!**

The queue workflow listens to the Netscaler HTTP Callout and will populate the Postgres queue database table.

- **The Digital Doorman**: Our queue workflow stands vigilant 24/7, listening for those NetScaler HTTP Callouts like a bouncer at an exclusive club.
- **Smart Traffic Cop**: The queue table acts as our brilliant buffer zone, keeping the "hearing about problems" part totally separate from the "dealing with problems" part. This way, even if processing gets backed up, we never miss a beat on incoming threats!
- **Repeat Offender Recognition**: Already seen this IP causing trouble? No problem! The system smartly updates timestamps for these persistent pests rather than creating duplicate entries.
- **VIP Waiting List**: New troublemakers get efficiently queued up for processing, ensuring everyone gets the special attention they deserve (though not the kind they were hoping for!).

This clever setup means your system stays resilient even when under heavy fire. If something hiccups downstream, all that juicy threat data stays safely tucked away until your system can deal with it properly. Think of it as your digital panic room where threat data goes to hide during the chaos!

Here's the clip of the queue workflow:


https://github.com/user-attachments/assets/ef2c982c-8422-4a79-8574-e4cd7031e1ef



### 3. Processing Workflow

**The Heart of the System: Processing Those Pesky IPs**

So what happens behind the scenes once our system spots a naughty IP? The magic happens on autopilot, thanks to a built-in scheduler that kicks things off:

- **Database Treasure Hunt**: First, we dig through the database to find all those unprocessed IPs waiting in line.
- **Smart Dataset Sorting**: Each IP gets automatically sorted into the right dataset bucket. If all the buckets are full? No problem! We just create a shiny new one on the fly.
- **Keeping Things Tidy**: We're neat freaks about our datasets. They'll never get too crowded since we cap them (normally at 50,000 IPs per dataset, but we've dialed it down to just 3 for testing - wouldn't want to block half the internet while we're experimenting, right?).
- **Real-Time Protection**: As soon as we spot trouble, we're on it! The system updates NetScaler's config instantly, so those troublemakers don't get a chance to cause more mischief.
- **Keeping Score**: Every IP we process gets flagged as "handled" in our database, giving us a crystal-clear trail of what's happened. Think of it as our system's diary where it logs all its heroic deeds!

*I like these lighting nodes*


https://github.com/user-attachments/assets/83549139-eee6-4660-8b08-4d74d22a1bf7



### 4. Clearing Workflow

**The Cleanup Crew: Taking Out the Digital Trash**

What happens to all those blocked IPs after they've served their time in digital jail? That's where our cleanup routine comes in:

- **Automatic Parole Board**: Our system regularly scans for IPs that have done their time (based on their TTL). No need for a human to review each case!
- **Spring Cleaning**: Once an IP's sentence is up, we quietly escort it out of the NetScaler dataset and update our counters. No muss, no fuss - they're free to go (unless they misbehave again, of course).
- **Keeping Everything Tidy**: The system makes sure our database and NetScaler are always on the same page. 
- **Certificate of Conduct**: the 'operation_log' database table will keep trace of each and every action taken towards an IP, we know who you are and what you have done!


https://github.com/user-attachments/assets/72e5f1f1-4458-494f-9e5b-ed9a54384884



### 5. Synchronization Workflow

**The Peacekeeper: Keeping Everyone on the Same Page**

What happens when your security team can't wait and makes emergency changes directly on Netscaler? No worries - our digital diplomat has got you covered:

- **Emergency Override Friendly**: Go ahead and make those urgent blocks directly in Netscaler when you're in firefighting mode, because you hadn't had the time to set up the right Netscaler policies yet.
- **Automatic Reconciliation**: Our system plays detective, noticing those manual changes and syncing them back to our central database. It's like having a friend who fixes your bookshelf after you frantically grabbed that reference book during a video call.
- **Smart Recognition**: The system is picky about what it syncs - it only grabs blocked IPs and datasets that follow our naming patterns. That way, it won't mess with your other NetScaler configurations or try to sync things it shouldn't!


https://github.com/user-attachments/assets/76f8b656-edf4-44fc-b0c5-abdc1a38867a



## Benefits of Implementing this Lightweight SOAR Initiative

- **Reduced Response Time**: Automate the detection-to-mitigation lifecycle, significantly accelerating your response to some security threats.
- **Operational Efficiency**: Minimize manual interventions, enabling security teams to dedicate their efforts to more strategic, high-value activities.
- **Enhanced Security Posture**: Provide immediate responses to emerging threats, thereby safeguarding your critical infrastructure and resources more effectively.
- **Flexible and Scalable**: This approach can be easily adapted to address evolving threat scenarios and scales naturally with the growth of your infrastructure.
- **Audit Trail**: Comprehensive logging of all system operations. This provides all necessary data for comprehensive analytics and visualization.

## Implementing the System

To implement this system, you'll need:

- An n8n server with an added Postgres instance (docker-compose provided for the whole system to be set up)
- Access to your Citrix NetScaler via its API
- A Google account for the configuration spreadsheet

The implementation process involves:

- Creating the n8n.domain.com reverse proxy for the n8n instance
- Setting up the database tables (database-schema.sql provided)
- Importing the n8n workflows
- Configuring the NetScaler API credentials
- Setting up Google API key for you email account (if using google email and Google Sheets)
- Running the initialization workflow
- Testing the system with a sample IP block request

## Tech stuff

Netscaler config example:

```
# Add the n8n backend
add server n8n.domain.com n8n.domain.com

# Add a service for the n8n backend
add service n8n-svc.domain.com n8n.domain.com SSL 443 -gslb NONE -maxClient 0 -maxReq 0 -cip DISABLED -usip NO -useproxyport YES -sp OFF -cltTimeout 180 -svrTimeout 360 -CKA YES -TCPB NO -CMP YES

# Set the SSL profile on the service
set ssl service n8n-svc.domain.com -sslProfile ns_default_ssl_profile_backend

# Add the LB vServer
add lb vserver n8n-lb.domain.com SSL 10.0.0.43 443 -persistenceType NONE -cltTimeout 180

# Set the SSL profile to the vServer
set ssl vserver n8n-lb.domain.com -sslProfile ns_default_ssl_profile_frontend

#Bind the service to the vServer
bind lb vserver n8n-lb.domain.comt n8n-svc.domain.com

#Bind the SSL certificate
bind ssl vserver n8n-lb.domain.com -certKeyName n8n.domain.com

# Add a HTTP Callout to the n8n webhook
add policy httpCallout ratelimit_callout -vServer n8n-lb.domain.com -returnType BOOL -hostExpr "HTTP.REQ.HEADER(\"Host\")" -urlStemExpr "\"/webhook-test/netscaler_rate_limit_webhook\"" -parameters ip(CLIENT.IP.SRC) attack_type("ratelimit") nsip(SYS.NSIP) -scheme https 

# Add a rate-limit identifier as example
add ns limitIdentifier sf_ratelimit -threshold 10 -timeSlice 600 -selectorName Top_CLIENTS

# Add a Responder Action that calls the HTP Callout
add responder action sf_ratelimit_action respondwith "SYS.NON_BLOCKING_HTTP_CALLOUT(ratelimit_callout)"

# Add a Responder Policy that gets the rate limit and trigger the action
add responder policy sf_ratelimit_pol "SYS.CHECK_LIMIT(\"sf_ratelimit\")" sf_ratelimit_action NOOP -logAction sf_ratelimit_action_called

# Bind the Responder Policy to a vServer (e.g. lb_storefront), can be bound to global for every vServer.
bind lb vserver storefront -policyName sf_ratelimit_pol -priority 90 -gotoPriorityExpression END -type REQUEST

# The Responder (DROP) policy
add responder policy "block_malicious_ips" "CLIENT.IP.SRC.CONTAINS_ANY(\"block_ip_list_1\")" DROP

# Bind that policy where you want, e.g. to a vServer:
bind lb vserver <vserver_name> -policyName block_malicious_ips -priority 10 -gotoPriorityExpression END -type REQUEST

# or globally:
bind responder global block_malicious_ips 10 END -type REQUEST
```

> **Please note:** the Responder (DROP) policy must be bound with the higher priority as it must be triggered first

### Netscaler user creation 

As a start, the following, limited, user privileges should work (not tested!).

```
# Add user
add system user n8n_block_IP 5b07e7c518466298e40db4 -encrypted -externalAuth DISABLED -timeout 900 -maxsession 20 -allowedManagementInterface API

# Add Command Policy
add system cmdPolicy n8n_block_IP ALLOW "(^save\\s+ns\\s+config)|(^save\\s+ns\\s+config\\s+.*)|(^add\\s+ns\\s+variable)|(^add\\s+ns\\s+variable\\s+.*)|(^set\\s+ns\\s+variable)|(^set\\s+ns\\s+variable\\s+.*)|(^add\\s+policy\\s+dataset)|(^add\\s+policy\\s+dataset\\s+.*)|(^bind\\s+policy\\s+dataset)|(^bind\\s+policy\\s+dataset\\s+.*)|(^unbind\\s+policy\\s+dataset)|(^unbind\\s+policy\\s+dataset\\s+.*)"

bind system user n8n_block_IP n8n_block_IP 1
```

Here you can download the five workflows, the database schema and the docker-compose (without the .env file) used in this exercise. As mentioned above, the docker-compose lets you download and run all the instances you need to run the whole system. Remember that as discussed at the beginning, the n8n server must be behind a reverse proxy (n8n.domain.com) for the HTTP Callout configuration to work properly and for being able to properly access the n8n GUI.
