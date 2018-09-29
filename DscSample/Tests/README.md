# Tests for Control Repo

The control repo is where the Config Data, DSC Configurations and Resources 
are finally composed into an end to end system configuration.

As the Config Data is the key source of Information, changes to the definitions should provide fast feedback.

As the managed objects (i.e. Nodes, AD Objects) definition should follow some rules (i.e. Naming conventions, configuration _templates_...). 
Those rules can be codified and enforced via tests (i.e. using pester).

Here's a few example of rules you could implement:
 - A Node object should have at least the properties `Name`,`NodeName`,`description` to be not null or empty
 - A Node object's `Name` should match one and only one Naming convention

The workflow associated with those tests is that upon a change, the author should run the tests to ensure he
 follows the rules set by those tests, before pushing his changes to a feature branch.
Upon a push (`git push`), and/or upon a Pull Request, the tests will run on a CI server, and invalidating the change if it fails, meaning only changes respecting those changes will be successful, and deployed.