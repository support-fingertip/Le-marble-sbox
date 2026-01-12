# SFDX Project

This repository contains a Salesforce DX project scaffold.

How to use
1. Install Salesforce CLI: https://developer.salesforce.com/tools/sfdxcli
2. Authorize an org: `sfdx auth:web:login -a DevHub`
3. Create a scratch org: `sfdx force:org:create -f config/project-scratch-def.json -a scratch -s -d 7`
4. Push source: `sfdx force:source:push`
