# Contributing to PowerShell Automation Toolkit

Thank you for your interest in contributing! This document provides guidelines and best practices for contributing to this project.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Guidelines](#development-guidelines)
- [PowerShell Style Guide](#powershell-style-guide)
- [Testing Requirements](#testing-requirements)
- [Documentation Standards](#documentation-standards)
- [Commit Message Guidelines](#commit-message-guidelines)
- [Pull Request Process](#pull-request-process)

## Code of Conduct

This project adheres to a code of professional conduct. By participating, you are expected to:

- Be respectful and inclusive
- Accept constructive criticism gracefully
- Focus on what is best for the community
- Show empathy towards other community members

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```powershell
   git clone https://github.com/iloveyouit/powershell-automation-toolkit.git
   ```
3. **Create a branch** for your changes:
   ```powershell
   git checkout -b feature/your-feature-name
   ```

## How to Contribute

### Reporting Bugs

Before submitting a bug report:
- Check existing issues to avoid duplicates
- Collect information about your environment
- Try to reproduce the issue

Include in your bug report:
- Clear description of the issue
- Steps to reproduce
- Expected vs actual behavior
- PowerShell version and OS details
- Error messages and logs
- Screenshots if applicable

### Suggesting Enhancements

Enhancement suggestions should include:
- Clear description of the proposed feature
- Use cases and benefits
- Potential implementation approach
- Any related scripts or examples

### Contributing Code

Types of contributions we welcome:
- New automation scripts
- Bug fixes
- Performance improvements
- Documentation improvements
- Test coverage expansion
- Security enhancements

## Development Guidelines

### Script Requirements

All scripts must include:

1. **Comment-Based Help**
   ```powershell
   <#
   .SYNOPSIS
       Brief description
   .DESCRIPTION
       Detailed description
   .PARAMETER ParameterName
       Parameter description
   .EXAMPLE
       Usage example
   .NOTES
       Additional information
   #>
   ```

2. **Parameter Validation**
   ```powershell
   [CmdletBinding(SupportsShouldProcess)]
   param(
       [Parameter(Mandatory=$true)]
       [ValidateNotNullOrEmpty()]
       [string]$ComputerName
   )
   ```

3. **Error Handling**
   ```powershell
   try {
       # Code logic
   }
   catch {
       Write-Error "Operation failed: $_"
       # Proper cleanup
   }
   finally {
       # Cleanup code
   }
   ```

4. **Logging Capability**
   ```powershell
   function Write-Log {
       param([string]$Message, [string]$Level = "INFO")
       $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
       "$timestamp [$Level] $Message" | Out-File $LogPath -Append
   }
   ```

## PowerShell Style Guide

### Naming Conventions

- **Functions**: Use approved verbs (Get-*, Set-*, New-*, Remove-*)
- **Variables**: Use camelCase for local, PascalCase for script scope
- **Parameters**: Use PascalCase
- **Constants**: Use UPPER_SNAKE_CASE

### Code Formatting

```powershell
# Good
if ($condition) {
    Do-Something
}
else {
    Do-SomethingElse
}

# Opening braces on same line
# Proper indentation (4 spaces)
# Space after if/foreach/while
```

### Best Practices

1. **Use Approved Verbs**
   ```powershell
   Get-Verb | Where-Object {$_.Verb -eq "YourVerb"}
   ```

2. **Support WhatIf and Confirm**
   ```powershell
   [CmdletBinding(SupportsShouldProcess)]
   param()
   
   if ($PSCmdlet.ShouldProcess($target, $operation)) {
       # Perform action
   }
   ```

3. **Write Verbose Output**
   ```powershell
   Write-Verbose "Processing server: $ComputerName"
   ```

4. **Use Pipeline Where Appropriate**
   ```powershell
   # Good
   Get-Process | Where-Object {$_.CPU -gt 10} | Select-Object Name, CPU
   
   # Avoid unnecessary loops
   ```

## Testing Requirements

### Minimum Testing

- Test on PowerShell 5.1 and PowerShell 7+
- Test on Windows Server 2016/2019/2022
- Verify error handling works correctly
- Test with invalid inputs
- Verify WhatIf and Confirm functionality

### Test Script Template

```powershell
Describe "Script-Name Tests" {
    Context "Parameter Validation" {
        It "Should reject null ComputerName" {
            { .\Script.ps1 -ComputerName $null } | Should -Throw
        }
    }
    
    Context "Functionality" {
        It "Should return expected output" {
            $result = .\Script.ps1 -ComputerName "localhost"
            $result | Should -Not -BeNullOrEmpty
        }
    }
}
```

## Documentation Standards

### README Requirements

Each script category should have:
- Overview of scripts in the category
- Common use cases
- Prerequisites
- Quick start examples
- Links to detailed documentation

### In-Script Documentation

```powershell
<#
.SYNOPSIS
    One-line description

.DESCRIPTION
    Detailed multi-line description
    of what the script does

.PARAMETER ComputerName
    Description of the parameter

.EXAMPLE
    .\Script.ps1 -ComputerName SERVER01
    Description of what this example does

.NOTES
    Author: Your Name
    Version: 1.0.0
    Last Modified: YYYY-MM-DD
    
.LINK
    https://github.com/iloveyouit/powershell-automation-toolkit
#>
```

## Commit Message Guidelines

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation changes
- **style**: Code style changes (formatting, etc.)
- **refactor**: Code refactoring
- **test**: Adding or updating tests
- **chore**: Maintenance tasks

### Examples

```
feat(azure): Add Azure AD Connect health monitoring script

- Implements comprehensive sync status checks
- Adds email alerting capability
- Includes detailed logging

Closes #123
```

## Pull Request Process

1. **Update Documentation**
   - Update README.md if adding new features
   - Update CHANGELOG.md with your changes
   - Ensure inline documentation is complete

2. **Run Tests**
   - Verify script works as expected
   - Test error scenarios
   - Validate on multiple OS versions

3. **Create Pull Request**
   - Clear title describing the change
   - Detailed description of modifications
   - Reference related issues
   - Include screenshots if applicable

4. **Code Review**
   - Address reviewer feedback
   - Make requested changes
   - Keep discussion professional

5. **Merge Requirements**
   - All checks must pass
   - At least one approval required
   - No merge conflicts
   - Documentation updated

## Questions?

- Open an issue for general questions
- Use GitHub Discussions for broader topics
- Review existing documentation first

## Recognition

Contributors will be:
- Listed in CONTRIBUTORS.md
- Credited in CHANGELOG.md
- Recognized in release notes

Thank you for contributing! 🎉
