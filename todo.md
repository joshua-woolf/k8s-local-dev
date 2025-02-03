Add credentials to k8s-dashboard.
Add dark mode to k8s-dashboard.
Add tests for the k8s-dashboard.
Refactor dashboard.
Look at Kubernetes Dashboard:
https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/
Refactor scripts.

Look at External DNS crashes.

```log
time="2025-02-03T15:28:26Z" level=info msg="config: {APIServerURL: KubeConfig: RequestTimeout:30s DefaultTargets:] GlooNamespaces:[gloo-system] SkipperRouteGroupVersion:zalando.org/v1 Sources:[service ingress traefik-proxy] Namespace: AnnotationFilter: LabelFilter: IngressClassNames:] FQDNTemplate: CombineFQDNAndAnnotation:false IgnoreHostnameAnnotation:false IgnoreIngressTLSSpec:false IgnoreIngressRulesSpec:false GatewayNamespace: GatewayLabelFilter: Compatibility: PublishInternal:false PublishHostIP:false AlwaysPublishNotReadyAddresses:false ConnectorSourceServer:localhost:8080 Provider:rfc2136 ProviderCacheTime:0s GoogleProject: GoogleBatchChangeSize:1000 GoogleBatchChangeInterval:1s GoogleZoneVisibility: DomainFilter:[local.dev] ExcludeDomains:] RegexDomainFilter: RegexDomainExclusion: ZoneNameFilter:] ZoneIDFilter:] TargetNetFilter:] ExcludeTargetNets:] AlibabaCloudConfigFile:/etc/kubernetes/alibaba-cloud.json AlibabaCloudZoneType: AWSZoneType: AWSZoneTagFilter:] AWSAssumeRole: AWSProfiles:] AWSAssumeRoleExternalID: AWSBatchChangeSize:1000 AWSBatchChangeSizeBytes:32000 AWSBatchChangeSizeValues:1000 AWSBatchChangeInterval:1s AWSEvaluateTargetHealth:true AWSAPIRetries:3 AWSPreferCNAME:false AWSZoneCacheDuration:0s AWSSDServiceCleanup:false AWSSDCreateTag:map] AWSZoneMatchParent:false AWSDynamoDBRegion: AWSDynamoDBTable:external-dns AzureConfigFile:/etc/kubernetes/azure.json AzureResourceGroup: AzureSubscriptionID: AzureUserAssignedIdentityClientID: AzureActiveDirectoryAuthorityHost: AzureZonesCacheDuration:0s CloudflareProxied:false CloudflareDNSRecordsPerPage:100 CloudflareRegionKey: CoreDNSPrefix:/skydns/ AkamaiServiceConsumerDomain: AkamaiClientToken: AkamaiClientSecret: AkamaiAccessToken: AkamaiEdgercPath: AkamaiEdgercSection: OCIConfigFile:/etc/kubernetes/oci.yaml OCICompartmentOCID: OCIAuthInstancePrincipal:false OCIZoneScope:GLOBAL OCIZoneCacheDuration:0s InMemoryZones:] OVHEndpoint:ovh-eu OVHApiRateLimit:20 PDNSServer:http://localhost:8081 PDNSServerID:localhost PDNSAPIKey: PDNSSkipTLSVerify:false TLSCA: TLSClientCert: TLSClientCertKey: Policy:sync Registry:txt TXTOwnerID:k8s TXTPrefix:external-dns- TXTSuffix: TXTEncryptEnabled:false TXTEncryptAESKey: Interval:15s MinEventSyncInterval:5s Once:false DryRun:false UpdateEvents:false LogFormat:text MetricsAddress::7979 LogLevel:info TXTCacheInterval:0s TXTWildcardReplacement: ExoscaleEndpoint: ExoscaleAPIKey: ExoscaleAPISecret: ExoscaleAPIEnvironment:api ExoscaleAPIZone:ch-gva-2 CRDSourceAPIVersion:externaldns.k8s.io/v1alpha1 CRDSourceKind:DNSEndpoint ServiceTypeFilter:] CFAPIEndpoint: CFUsername: CFPassword: ResolveServiceLoadBalancerHostname:false RFC2136Host:bind9 RFC2136Port:53 RFC2136Zone:[local.dev] RFC2136Insecure:false RFC2136GSSTSIG:false RFC2136CreatePTR:false RFC2136KerberosRealm: RFC2136KerberosUsername: RFC2136KerberosPassword: RFC2136TSIGKeyName:externaldns-key RFC2136TSIGSecret:****** RFC2136TSIGSecretAlg:hmac-sha256 RFC2136TAXFR:true RFC2136MinTTL:0s RFC2136BatchChangeSize:50 RFC2136UseTLS:false RFC2136SkipTLSVerify:false NS1Endpoint: NS1IgnoreSSL:false NS1MinTTLSeconds:0 TransIPAccountName: TransIPPrivateKeyFile: DigitalOceanAPIPageSize:50 ManagedDNSRecordTypes:[A AAAA CNAME] ExcludeDNSRecordTypes:] GoDaddyAPIKey: GoDaddySecretKey: GoDaddyTTL:0 GoDaddyOTE:false OCPRouterName: IBMCloudProxied:false IBMCloudConfigFile:/etc/kubernetes/ibmcloud.json TencentCloudConfigFile:/etc/kubernetes/tencent-cloud.json TencentCloudZoneType: PiholeServer: PiholePassword: PiholeTLSInsecureSkipVerify:false PluralCluster: PluralProvider: WebhookProviderURL:http://localhost:8888 WebhookProviderReadTimeout:5s WebhookProviderWriteTimeout:10s WebhookServer:false TraefikDisableLegacy:true TraefikDisableNew:false NAT64Networks:]}"
time="2025-02-03T15:28:26Z" level=info msg="Instantiating new Kubernetes client"
time="2025-02-03T15:28:26Z" level=info msg="Using inCluster-config based on serviceaccount-token"
time="2025-02-03T15:28:26Z" level=info msg="Created Kubernetes client https://10.96.0.1:443"
time="2025-02-03T15:28:26Z" level=info msg="Using inCluster-config based on serviceaccount-token"
time="2025-02-03T15:28:26Z" level=info msg="Created Dynamic Kubernetes client https://10.96.0.1:443"
time="2025-02-03T15:29:26Z" level=fatal msg="failed to sync traefik.io/v1alpha1, Resource=ingressroutes: context deadline exceeded"
stream closed EOF for dns/external-dns-589b448768-hm7br (external-dns)
```

Switch to using cloud-provider-kind to setup a load balancer rather than using node ports.

Change entire setup to use flux for deployment.
Convert script to powershell.

Add dashboards to Grafana for flagger and load tester.
Refine dashboards.

Make the repository presentable.

Future enhancements:
  - mTLS
  - Network Policies
  - Resource Requests and Limits
  - Secure Connections
  - Service Mesh
  - Storage
