# ITAM (IT Asset Management)
Make your IT Asset Management process simple and controlled. This complete web-based application for tracking computer equipment, software licenses, and accessories in the organization, will make it happen.

<img src="https://cdn3d.iconscout.com/3d/premium/thumb/asset-allocation-3d-icon-download-in-png-blend-fbx-gltf-file-formats--finance-management-8825126.png?f=webp" width="350" height="350" />

## Table Of Contents
1. [Introduction](#1-introduction)<br>
2. [Code Explanations and Data Structure](#2-code-explanations-and-data-structure)<br>
3. [Deployment Process](#3-deployment-process)<br>
4. [License](#4-license)<br>
5. [Authors](#5-authors)<br>
6. [Previous Versions](#6-previous-versions)<br>
7. [Feedback](#7-feedback)<br>
TBA

## 1. Introduction
Why we have decided to made this application? The answer is pretty simple - every IT department needs asset tracking management system.
It prevents equipment loss, tracks costs, manages assignments in every organization.

## 2. Code Explainations and Data Structure
Architecture Evolution of the Project:
<br>TBA

### Project Files
- :file_folder: *`.github`* folder contains CICD workflows
    - :file_folder: *`workflows`* subfolder contains CICD pipelines file
        - :file_folder: *`tests`* subfolder contains test file for CICD process
            - :page_facing_up: *`test_main.py`* test file for CICD pipelines
        - :page_facing_up: *`cicd.yml`* CICD pipelines
- :file_folder: *`app`* folder contains all application data
    - :file_folder: *`dummy-data`* subfolder contains dummy data JSON files
        - :page_facing_up: *`items.json`* items dummy data JSON file
        - :page_facing_up: *`users.json`* users dummy data JSON file
    - :file_folder: *`website`* subfolder contains pre-rendered .html pages for the website
        - :page_facing_up: *`add_item.html`*
        - :page_facing_up: *`add_user.html`*
        - :page_facing_up: *`assign_item.html`*
        - :page_facing_up: *`base.html`*
        - :page_facing_up: *`delete_item.html`*
        - :page_facing_up: *`index.html`*
        - :page_facing_up: *`modify_item_form.html`* 
        - :page_facing_up: *`modify_item_select.html`*
        - :page_facing_up: *`show_stock_items.html`* 
        - :page_facing_up: *`show_user_items_select.html`*
        - :page_facing_up: *`show_user_items.html`*
        - :page_facing_up: *`show_users.html`*
        - :page_facing_up: *`stock_by_categoeirs.html`*
    - :page_facing_up: *`app.py`* main application file
    - :page_facing_up: *`storage.py`* storage file for operating with persistent storage
- :file_folder: *`docker`* folder contains Docker deployment data
    - :page_facing_up: *`Dockerfile`* configuration file for Docker environment
- :file_folder: *`iac`* folder contains IaC deployment data
    - :file_folder: *`scripts`* subfolder contains user data scripts for control plane and workers deployment
        - :page_facing_up: *`user-data-control-plane.sh`*
        - :page_facing_up: *`user-data-worker.sh`*
    - :file_folder: *`terraform`* subfolder contains AWS deployment data
        - :page_facing_up: *`alb.tf`* Load Balancer
        - :page_facing_up: *`ec2.tf`* EC2 instances
        - :page_facing_up: *`keypair.tf`* Keypair
        - :page_facing_up: *`network.tf`* Network (VPC, Subnets, IGW, Routes)
        - :page_facing_up: *`outputs.tf`* AWS Environment Outputs Data
        - :page_facing_up: *`providers.tf`* Terraform Providers
        - :page_facing_up: *`sg.tf`* Security Groups
        - :page_facing_up: *`terraform.tfvars`* Terraform Tfvars
        - :page_facing_up: *`variables.tf`* Terraform Variables
- :page_facing_up: *`LICENSE`* License Information
- :page_facing_up: *`README.md`* Readme File
- :page_facing_up: *`USER-GUIDE.md`* Application Usage User Guide


<br>TBA

## 3. Deployment Process
TBA

## 4. License
[![GPLv3 License](https://img.shields.io/badge/License-GPL%20v3-yellow.svg)](https://github.com/dcoacher/ITAM/blob/main/LICENSE)

## 5. Authors
As for the previous versions, this project version is a result of the great collaboration of the two developers:
- Desmond Coacher - [@dcoacher](https://github.com/dcoacher)
- Artiom Krits - [@ArtiomKrits92](https://github.com/ArtiomKrits92)

## 6. Previous Versions
**Name:** [IT Asset Management](https://github.com/dcoacher/it-asset-management)<br>
**Version:** 1.0<br>
**Release date:** July 28, 2025

## 7. Feedback
If you have any feedback, feel free to contact us via email: 
- [Desmond Coacher](mailto:dcoacher@outlook.com)
- [Artiom Krits](mailto:artiomkrits92@gmail.com)
