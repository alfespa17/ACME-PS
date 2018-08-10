function Get-ServiceDirectory {
    <#
        .SYNOPSIS
            Fetches the ServiceDirectory from an ACME Servers.

        .DESCRIPTION
            This will issue a web request to either the url or to a well-known ACME server to fetch the service directory.
            Alternatively the directory can be loaded from a path, when it has been stored with Export-CliXML or as Json.

        
        .PARAMETER EndpointName
            The Name of an Well-Known ACME-Endpoint.
        
        .PARAMETER DirectoryUrl
            Url of an ACME Directory.
        
        .PARAMETER Path
            Path to load the Directory from. The given file needs to be .json or .xml (CLI-Xml)
        
        .PARAMETER AutomaticDirectoryHandling
            If set, the loaded service collection will be set as Module-Scoped variable. 
            Other functions needing Urls from the service collection will be able to determine them automatically.
        
        .PARAMETER AutomaticNonceHandling
            If set, the nonce will be initialized and handled by the module. You can access the current Nonce by calling Get-Nonce.


        .EXAMPLE
            PS> Get-ServiceDirectory

        .EXAMPLE
            PS> Get-ServiceDirectory "LetsEncrypt"

        .EXAMPLE
            PS> Get-ServiceDirectory "LetsEncrypt" -AutomaticDirectoryHandling -AutomaticNonceHandling

        .EXAMPLE
            PS> Get-ServiceDirectory -DirectoryUrl "https://acme-staging-v02.api.letsencrypt.org"
    #>
    [CmdletBinding(DefaultParameterSetName="FromName")]
    [OutputType("ACMEDirectory")]
    param(
        [Parameter(Position=0, ParameterSetName="FromName")]
        [string]
        $ServiceName = "LetsEncrypt-Staging",

        [Parameter(Mandatory=$true, ParameterSetName="FromUrl")]
        [Uri]
        $DirectoryUrl,

        [Parameter(Mandatory=$true, ParameterSetName="FromPath")]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [Parameter()]
        [Switch]
        $AutomaticDirectoryHandling,

        [Parameter()]
        [Switch]
        $AutomaticNonceHandling
    )

    begin {
        $KnownEndpoints = @{ 
            "LetsEncrypt-Staging"="https://acme-staging-v02.api.letsencrypt.org";
            "LetsEncrypt"="https://acme-v02.api.letsencrypt.org" 
        }
    }

    process {
        $ErrorActionPreference = 'Stop';

        if($PSCmdlet.ParameterSetName -in @("FromName", "FormUrl")) {
            if($PSCmdlet.ParameterSetName -eq "FromName") {
                $acmeBaseUrl = $KnownEndpoints[$ServiceName];
                if($acmeBaseUrl -eq $null) {
                    $knownNames = $KnownEndpoints.Keys -join ", "
                    throw "The ACME-Service-Name $ServiceName is not known. Known names are $knownNames."
                }

                $serviceDirectoryUrl = "$acmeBaseUrl/directory"
            } elseif ($PSCmdlet.ParameterSetName -eq "FromUrl") {
                $serviceDirectoryUrl = $DirectoryUrl
            }
            
            $response = Invoke-WebRequest $serviceDirectoryUrl;

            $result = [AcmeDirectory]::new(($response.Content | ConvertFrom-Json));
        }

        if($PSCmdlet.ParameterSetName -eq "FromPath") {
            if($Path -like "*.json") {
                $result = [ACMEDirectory](Get-Content $Path | ConvertFrom-Json)
            } else {
                $result = [AcmeDirectory](Import-Clixml $Path)
            }
        }

        if($AutomaticDirectoryHandling) {
            Enable-ServiceDirectoryHandling -ServiceDirectory $result;
        }

        if($AutomaticNonceHandling) {
            $nonce = New-Nonce -Directory $result;
            Enable-NonceHandling -Nonce $nonce -NewNonceUrl $result.NewNonce;
        }

        return $result;
    }
}