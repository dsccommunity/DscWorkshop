# Description

The DSC resource `FileSystemAccessRule` will manage permissions on paths
in the file system.

If the parameter `Rights` is not used or no rights are provided (using
`Rights = @()`), and `Ensure` is set to `'Absent'` then all the allow
access rules for the identity will be removed. If specific rights are
specified then only those rights will be removed when `Ensure` is set to
`'Absent'`.

When calling the method `Get` the property `Ensure` will be set to `'Present'`
if the identity is found with an access rule on the specified path.

If the resource is used for a path that belongs to a Windows Server Failover
Cluster's cluster disk partition and if the node it runs on is not the
active node, then the method `Get` will return the value `Present` for
the property `Ensure`, but the property `Rights` will be empty.

## Requirements

- Currently only works with the Windows file system.
