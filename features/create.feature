Feature: upload an app to the apps marketplace
  Background: create a new zendesk app

  Scenario: package a zendesk app by running 'zat create --no-install' command
    Given an app is created in directory "tmp/aruba"
    Given a .zat file in "tmp/aruba"
    When I run the command "zat create --path tmp/aruba --no-install" to create the app
    And the command output should contain "info  Checking for new version of zendesk_apps_tools"
    And the command output should contain "validate  OK"
    And the command output should contain "package  created"
    And the command output should contain "Status  working"
    And the command output should contain "Create  OK"
    And the zip file should exist in directory "tmp/aruba/tmp"

  Scenario: invalid app - missing manifest.json
    Given an app is created in directory "tmp/aruba"
    Given I remove file "tmp/aruba/manifest.json"
    When I run the command "zat create --path tmp/aruba --no-install" to validate the app
    Then the command output should contain "Could not find manifest.json"

  Scenario: invalid manifest.json - duplicate keys
    When I edit file "tmp/aruba/manifest.json" and add duplicate keys
    When I run the command "zat create --path tmp/aruba" to validate the app
    Then the command output should contain "Duplicate reference in manifest:"

  Scenario: invalid manifest.json - duplicate keys
    When I edit file "tmp/aruba/manifest.json" to invalid json
    When I run the command "zat create --path tmp/aruba" to validate the app
    Then the command output should contain "manifest is not proper JSON"