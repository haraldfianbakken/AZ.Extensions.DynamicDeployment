# AZ.Extensions.DynamicDeployment
Did you ever wish you could inject the content of Powershell variables or use a Powershell function together with your ARM Templates - to do even more with your ARM templates? Fear not - this is an attempt to allow you do just that! 

This module allows you to input a template or a params file and dynamically evaluate the expression passed - injecting the values. 

The returned value can be used and passed as a complete template or as params to a template deployment. 

Disclaimer: Module comes with no warrenty, use at own risk. 

## Current support
 - Parameters in template file (Evaluating and setting default value)
 - Parameters from parameters file (Evaluating and setting value)

## What you can do?
- Inject variable contents
- Inject function return values
- Dynamic evaluation on parameters on deployment
- Dynamic evaluation/injection for default values on template

## Syntax
To have the 'evaluator' work - you need to add a 'magic' string in your files with. The magic string has the following format : $pwsh[<$variable>] $pwsh[{<func_with_variables}]

## How evaluation is performed
- $pwsh[] is checked for; if it's present - the expression will start the evaluation 
- Variables are injected into the string
- if {} was present in the string - the expression inside the string is evaluated (after variable expansion) - hence allowing fairly complex functions to evaluate together with variable contents

Because $pwsh[] has a special meaning - this means you can never have a value with this exact string if you are to use this module. Unless adding support for custom expression (which is there, but not exposed yet)

## Example evaluation (Template file & deployment)
Here's some examples on how you could use it

    # Given the following Powershell session (and logged in to azure)
    Import-Module Az.Extensions.DynamicDeployment

    function Get-SomeData($testParam){ 
            "Hello $testParam" 
    }
    $myVar = 'TestingVariable'
    $storageNameFromPS = 'mystorageaccount'

Given the following template file ([ExpressionDeploy.json](Templates/ExpressionDeploy.json)):

     "parameters": {
        "simple": {
            "type": "string",
            "defaultValue":  "$pwsh[$storageNameFromPS]"
        },
        "paramUsingFuncEvaluator": {
            "type": "string",
            "defaultValue":  "$pwsh[{(Get-SomeData -testParam '$storageNameFromPS')}]"
        },
        complexEvaluator: {
            "type": "string",
            "defaultValue": "$pwsh[{((Get-AzStorageAccount)[0]).StorageAccountName}]"
        }
     }

Deploy this file and evaluate 
    
    # From same Powershell session
    $template = Expand-AzTemplate -TemplateFile .\Templates\ExpressionDeploy.json 
    $deployment = New-AzResourceGroupDeployment -TemplateObject $template -ResourceGroup 'test-RG' -Verbose
    # What was injected and deployed
    $deployment
    # Showing parts of output here only.
    Outputs                 :
                          Name                       Type                       Value
                          =========================  =========================  ==========
                          paramUsingFuncEvaluator    String                     Hello TestingVariable
                          paramSimpleExpression      String                     mystorageaccount
                          paramComplexEvaluator      String                     devopsdemoapib081

## Example 2 - Params (if you want to keep your template file clean)    
    # NB: Assume same variables & functions in session as previous example
    $params = Expand-AzParameters -templateParameterFile .\Template\ExpressionDeploy.params.json
    $deployment = New-AzResourceGroupDeployment -TemplateFile .\Templates\ExpressionDeployClean.json -TemplateParameterObject $params -ResourceGroup 'test-RG' -Verbose
    $deployment
    # Shortened for the readability
    Outputs                 :
                          Name                       Type                       Value
                          =========================  =========================  ==========
                          paramSimpleExpression      String                     mystorageaccount
                          paramComplexEvaluator      String                     devopsdemoapib081
                          paramUsingFuncEvaluator    String                     Hello TestingVariable
# Usage
## Requirements
 - Powershell 7 and higher (might work with lower versions, but untested)
 - AZ.Resources module 

## Installation
    Install-Module Az.Extensions.DynamicDeployment

    # Verify that you have 2 functions
    Get-Command -Module Az.Extensions.DynamicDeployment



## Potentially addons
 - Add support for same in variables section
