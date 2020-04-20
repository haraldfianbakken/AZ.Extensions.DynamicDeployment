function Get-ExpandedString {
    [cmdletbinding()]
    param($data, $prefix='$pwsh[', $lastChar=']')
    
    if($data -and $data.IndexOf($prefix) -gt -1 -and $data.EndsWith($lastChar)){
        Write-Verbose "Expanding $data"
        $data = $data.Replace($prefix,'');
        $data = $data.Substring(0, $data.length-1)
        $hasFunctionStart = $data.IndexOf('{');
        $hasFunctionEnd = $data.IndexOf('}');
        $expandedString = $ExecutionContext.InvokeCommand.ExpandString($data)
        # Allow expressions such as a($b) or a(-paramName '$b') translating into a -paramName 'value'
        if($hasFunctionStart -gt -1 -and $hasFunctionEnd -gt -1){
            $expandedString = $expandedString.Substring($expandedString.IndexOf('{')+1, $expandedString.IndexOf('}')-1)
            $expandedString = Invoke-Expression $expandedString
        }
        return $expandedString
    } else {
        Write-Verbose "Value does not have magic string format"
        return $data
    }    
}
function Get-FileContentFromUri {
    [cmdletbinding()]
    param (
        $uri
    )
    $tempFile = New-TemporaryFile;
    [void](Invoke-WebRequest -uri $uri -OutFile $tempFile.FullName)
    return (Get-Content $file.FullName)    
}

<#
.SYNOPSIS
    Parses a parameters file/uri and returns the expanded parameters in a hashtable to be used for deployment
.DESCRIPTION
    Returns a hashtable to be used for deployment, with values expanded - supporting Powershell variables and simple expressions
.EXAMPLE
    PS C:\> Add-AzAccount 
    PS C:\> $myVar = 'The Variable Content 
    PS C:\> $params = Expand-AZParameters -TemplateParameterUri 'https://www.github.com/haraldfianbakken/Az.Extensions.DynamicDeployment/Templates/Simple.Params.json
    PS C:\> $params
    PS C:\> New-AZResourceGroupDeployment -TemplateUri https://www.github.com/haraldfianbakken/Az.Extensions.DynamicDeployment/Templates/Simple.json -TemplateParameterObject $params
    Sets the variable found in the dynamics parameters and expands it.
    You can use the params in any deployment as fit. 
.EXAMPLE
    PS C:\> Add-AzAccount 
    PS C:\> function func($testParam){ "Hello $testParam"}
    PS C:\> $params = Expand-AZParameters -TemplateParameterUri 'https://www.github.com/haraldfianbakken/Az.Extensions.DynamicDeployment/Templates/UsingFunc.Params.json    
    PS C:\> New-AZResourceGroupDeployment -TemplateObject $template -TemplateParameterObject $params    
.EXAMPLE
    PS C:\> Add-AzAccount 
    PS C:\> $params = Expand-AZParameters -TemplateParameterUri 'https://www.github.com/haraldfianbakken/Az.Extensions.DynamicDeployment/Templates/Complex.Params.json    
    PS C:\> New-AZResourceGroupDeployment -TemplateObject $template -TemplateParameterObject $params    
    This demonstates a complex template - which has an expression - calling out to ARM, selecting your Storage accounts (first one) and its name into the parameter.    
.INPUTS
    -TemplateParameterUri
    Uri of the parameters file 
    -TemplateParameterFile
    Local path of the parameters file
.OUTPUTS
    Hashtable of expanded variables
#>
function Expand-AzParameters {
    [cmdletbinding()]
    param(
        [Parameter(Position = 0, Mandatory=$true, ParameterSetName = 'UriSet')]
        [Uri]    
        $templateParameterUri,
        [Parameter(Position = 0, Mandatory=$true, ParameterSetName = 'FileSet')]
        [String]    
        $templateParameterFile
    )
    begin {
        $content = "";
        switch ($PSCmdlet.ParameterSetName) {
            'UriSet' {
                $content = Get-FileContentFromUri -uri $templateParameterUri;
            }
            'FileSet' {
                $content = Get-Content $templateParameterFile -Raw;
            }
        }
        
        $paramsJson = $content | ConvertFrom-Json 

        if($paramsJson.'$schema'.IndexOf('deploymentParameters.json') -eq -1){
            Write-Error 'Invalid parameters file passed'
            exit 1;
        }

        $paramsAsHashTable = $content | ConvertFrom-Json -AsHashtable
    } 
    process {
        $paramsAsHashTable.parameters.Keys|ForEach-Object {
            $paramsJson.parameters."$_".value = Get-ExpandedString -data $paramsJson.parameters."$_".value
        }
    }
    end {
        $paramsObject=$paramsJson.parameters;
        # Parmas Object needs to be simpler 
        $o = @{}
        $paramsAsHashTable.parameters.keys|ForEach-Object {
            $o.Add($_, $paramsJson.parameters."$_".Value)
        }
        return $o;
        # $paramsJson|ConvertTo-Json
        # return $paramsObject|ConvertTo-Json|ConvertFrom-Json -AsHashtable;                

    }
}

<#
.SYNOPSIS
    Parses a parameters file/uri and returns the expanded template in a hashtable to be used for deployment
.DESCRIPTION
    Returns a hashtable to be used for deployment - with default values (parameters) expanded - supporting Powershell variables and simple expressions
.EXAMPLE
    PS C:\> Add-AZAccount
    PS C:\> $myVar = 'The Variable Content 
    PS C:\> $template = Expand-AzTemplate -TemplateParameterUri 'https://www.github.com/haraldfianbakken/Az.Extensions.DynamicDeployment/Templates/Simple.json
    PS C:\> $template
    PS C:\> New-AZResourceGroupDeployment -TemplateObject $template -TemplateParameterUri $paramsUri
    
    Expanding variables from Powershell into the default value params. 
.EXAMPLE
    PS C:\> Add-AzAccount 
    PS C:\> function func($testParam){ "Hello $testParam"}
    PS C:\> $template = Expand-AzTemplate -TemplateParameterUri 'https://www.github.com/haraldfianbakken/Az.Extensions.DynamicDeployment/Templates/UsingFunc.json
    PS C:\> $template    
    PS C:\> New-AZResourceGroupDeployment -TemplateObject $template -TemplateParameterUri $paramsUri
    
    Showing how to create a function returning a value that is expanded into the template before deployment
        
.EXAMPLE
    PS C:\> Add-AzAccount 
    PS C:\> $params = Expand-AzTemplate -TemplateParameterUri 'https://www.github.com/haraldfianbakken/Az.Extensions.DynamicDeployment/Templates/Complex.json    
    PS C:\> $template
    PS C:\> New-AZResourceGroupDeployment -TemplateObject $template -TemplateParameterUri $paramsUri
    
    This demonstates a complex template - which has an expression - calling out to ARM, selecting your Storage accounts (first one) and its name into the parameter.    

.INPUTS
    -TemplateUri
    Uri of the template file 
    -TemplateFile
    Local path of the template file
.OUTPUTS
    Hashtable of expanded variables
#>
function Expand-AzTemplate {
    [cmdletbinding()]
    param(
        [Parameter(Position = 0, Mandatory=$true, ParameterSetName = 'UriSet')]
        [Uri]    
        $templateUri,
        [Parameter(Position = 0, Mandatory=$true, ParameterSetName = 'FileSet')]
        [String]    
        $templateFile
    )
    begin {
        $content = "";
        switch ($PSCmdlet.ParameterSetName) {
            'UriSet' {
                $content = Get-FileContentFromUri -uri $templateUri;
            }
            'FileSet' {
                $content = Get-Content $templateFile -Raw;
            }
        }
        
        $templateJson = $content | ConvertFrom-Json 

        if($templateJson.'$schema'.IndexOf('deploymentTemplate.json') -eq -1){
            Write-Error 'Invalid parameters file passed'
            exit 1;
        }

        $templateAsHashTable = $content | ConvertFrom-Json -AsHashtable
    } 
    process {
        $templateAsHashTable.parameters.Keys|ForEach-Object {
            if($templateJson.parameters."$_".defaultvalue){
                $templateJson.parameters."$_".defaultvalue = Get-ExpandedString -data $templateJson.parameters."$_".defaultvalue
            } else {
                Write-Verbose "$_ does not have a default value"
            }            
        }
    }
    end {
        return $templateJson|ConvertTo-Json|ConvertFrom-Json -AsHashtable;    
    }
}