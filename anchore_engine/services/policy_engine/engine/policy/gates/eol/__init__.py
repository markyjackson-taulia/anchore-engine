"""
By convention, we move eol'd gates into this module to keep them separated and avoid naming conflicts for classes.

"""
from anchore_engine.services.policy_engine.engine.policy.gate import Gate, BaseTrigger, LifecycleStates


class SuidModeDiffTrigger(BaseTrigger):
    __trigger_name__ = 'suidmodediff'
    __description__ = 'triggers if file is suid, but mode is different between the image and its base'
    __lifecycle_state__ = LifecycleStates.eol


class SuidFileAddTrigger(BaseTrigger):
    __trigger_name__ = 'suidfileadd'
    __description__ = 'triggers if the evaluated image has a file that is SUID and the base image does not'
    __lifecycle_state__ = LifecycleStates.eol


class SuidFileDelTrigger(BaseTrigger):
    __trigger_name__ = 'suidfiledel'
    __description__ = 'triggers if the base image has a SUID file, but the evaluated image does not'
    __lifecycle_state__ = LifecycleStates.eol


class SuidDiffTrigger(BaseTrigger):
    __trigger_name__ = 'suiddiff'
    __description__ = 'triggers if any one of the other events for this gate have triggered'
    __lifecycle_state__ = LifecycleStates.eol


class SuidDiffGate(Gate):
    __lifecycle_state__ = LifecycleStates.eol
    __gate_name__ = 'suiddiff'
    __description__ = 'SetUID File Checks'
    __triggers__ = [
        SuidDiffTrigger,
        SuidFileAddTrigger,
        SuidFileDelTrigger,
        SuidModeDiffTrigger
    ]


class BaseOutOfDateTrigger(BaseTrigger):
    __trigger_name__ = 'baseoutofdate'
    __description__ = 'triggers if the image\'s base image has been updated since the image was built/analyzed'
    __params__ = {}
    __lifecycle_state__ = LifecycleStates.eol


class ImageCheckGate(Gate):
    __gate_name__ = 'imagecheck'
    __description__ = 'Checks on image ancestry'
    __triggers__ = [BaseOutOfDateTrigger]
    __lifecycle_state__ = LifecycleStates.eol


class PkgDiffTrigger(BaseTrigger):
    __trigger_name__ = 'pkgdiff'
    __description__ = 'triggers if any one of the other events has triggered'
    __lifecycle_state__ = LifecycleStates.eol


class PkgVersionDiffTrigger(BaseTrigger):
    __trigger_name__ = 'pkgversiondiff'
    __description__ = 'triggers if the evaluated image has a package installed with a different version of the same package from a previous base image'
    __lifecycle_state__ = LifecycleStates.eol


class PkgAddTrigger(BaseTrigger):
    __trigger_name__ = 'pkgadd'
    __description__ = 'triggers if image contains a package that is not in its base'
    __lifecycle_state__ = LifecycleStates.eol


class PkgDelTrigger(BaseTrigger):
    __trigger_name__ = 'pkgdel'
    __description__ = 'triggers if image has removed a package that is installed in its base'
    __lifecycle_state__ = LifecycleStates.eol


class PkgDiffGate(Gate):
    __lifecycle_state__ = LifecycleStates.eol
    __gate_name__ = 'pkgdiff'
    __description__ = 'Distro Package Difference Checks From Base Image'
    __triggers__ = [
        PkgVersionDiffTrigger,
        PkgAddTrigger,
        PkgDelTrigger,
        PkgDiffTrigger
    ]


class LowSeverityTrigger(BaseTrigger):
    __trigger_name__ = 'vulnlow'
    __description__ = 'Checks for "low" severity vulnerabilities found in an image'
    __vuln_levels__ = ['Low']
    __lifecycle_state__ = LifecycleStates.eol


class MediumSeverityTrigger(BaseTrigger):
    __trigger_name__ = 'vulnmedium'
    __description__ = 'Checks for "medium" severity vulnerabilities found in an image'
    __vuln_levels__ = ['Medium']
    __lifecycle_state__ = LifecycleStates.eol


class HighSeverityTrigger(BaseTrigger):
    __trigger_name__ = 'vulnhigh'
    __description__ = 'Checks for "high" severity vulnerabilities found in an image'
    __vuln_levels__ = ['High']
    __lifecycle_state__ = LifecycleStates.eol


class CriticalSeverityTrigger(BaseTrigger):
    __trigger_name__ = 'vulncritical'
    __description__ = 'Checks for "critical" severity vulnerabilities found in an image'
    __vuln_levels__ = ['Critical']
    __lifecycle_state__ = LifecycleStates.eol


class UnknownSeverityTrigger(BaseTrigger):
    __trigger_name__ = 'vulnunknown'
    __description__ = 'Checks for "unkonwn" or "negligible" severity vulnerabilities found in an image'
    __vuln_levels__ = ['Unknown', 'Negligible', None]
    __lifecycle_state__ = LifecycleStates.eol


class FeedOutOfDateTrigger(BaseTrigger):
    __trigger_name__ = 'feedoutofdate'
    __description__ = 'Fires if the CVE data is older than the window specified by the parameter MAXAGE (unit is number of days)'
    __lifecycle_state__ = LifecycleStates.eol


class UnsupportedDistroTrigger(BaseTrigger):
    __trigger_name__ = 'unsupporteddistro'
    __description__ = 'Fires if a vulnerability scan cannot be run against the image due to lack of vulnerability feed data for the images distro'
    __lifecycle_state__ = LifecycleStates.eol


class AnchoreSecGate(Gate):
    __gate_name__ = 'anchoresec'
    __description__ = 'Vulnerability checks against distro packages'
    __lifecycle_state__ = LifecycleStates.eol
    __superceded_by__ = 'vulnerabilities'

    __triggers__ = [
        LowSeverityTrigger,
        MediumSeverityTrigger,
        HighSeverityTrigger,
        CriticalSeverityTrigger,
        UnknownSeverityTrigger,
        FeedOutOfDateTrigger,
        UnsupportedDistroTrigger
    ]


class VerifyTrigger(BaseTrigger):
    __lifecycle_state__ = LifecycleStates.eol
    __trigger_name__ = 'verify'
    __description__ = 'Check package integrity against package db in in the image. Triggers for changes or removal or content in all or the selected DIRS param if provided, and can filter type of check with the CHECK_ONLY param'


class PkgNotPresentTrigger(BaseTrigger):
    __lifecycle_state__ = LifecycleStates.eol
    __trigger_name__ = 'pkgnotpresent'
    __description__ = 'triggers if the package(s) specified in the params are not installed in the container image. The parameters specify different types of matches.',


class PackageCheckGate(Gate):
    __gate_name__ = 'pkgcheck'
    __description__ = 'Distro package checks'
    __lifecycle_state__ = LifecycleStates.eol
    __superceded_by__ = 'packages'
    __triggers__ = [
        PkgNotPresentTrigger,
        VerifyTrigger
    ]

class EffectiveUserTrigger(BaseTrigger):
    __lifecycle_state__ = LifecycleStates.eol
    __trigger_name__ = 'effectiveuser'
    __description__ = 'Triggers if the effective user for the container is either root when not allowed or is not in a whitelist'


class DirectiveCheckTrigger(BaseTrigger):
    __lifecycle_state__ = LifecycleStates.eol
    __trigger_name__ = 'directivecheck'
    __description__ = 'Triggers if any directives in the list are found to match the described condition in the dockerfile'


class ExposeTrigger(BaseTrigger):
    __lifecycle_state__ = LifecycleStates.eol
    __trigger_name__ = 'expose'
    __description__ = 'triggers if Dockerfile is EXPOSEing ports that are not in ALLOWEDPORTS, or are in DENIEDPORTS'


class NoFromTrigger(BaseTrigger):
    __lifecycle_state__ = LifecycleStates.eol
    __trigger_name__ = 'nofrom'
    __params__ = None
    __description__ = 'triggers if there is no FROM line specified in the Dockerfile'


class FromScratch(BaseTrigger):
    __lifecycle_state__ = LifecycleStates.eol
    __trigger_name__ = 'fromscratch'
    __description__ = 'triggers the FROM line specified "scratch" as the parent'


class NoTag(BaseTrigger):
    __lifecycle_state__ = LifecycleStates.eol
    __trigger_name__ = 'notag'
    __description__ = 'triggers if the FROM container specifies a repo but no explicit, non-latest tag'


class Sudo(BaseTrigger):
    __lifecycle_state__ = LifecycleStates.eol
    __trigger_name__ = 'sudo'
    __description__ = 'triggers if the Dockerfile contains operations running with sudo'


class VolumePresent(BaseTrigger):
    __trigger_name__ = 'volumepresent'
    __description__ = 'triggers if the Dockerfile contains a VOLUME line'
    __lifecycle_state__ = LifecycleStates.eol


class NoHealthCheck(BaseTrigger):
    __trigger_name__ = 'nohealthcheck'
    __description__ = 'triggers if the Dockerfile does not contain any HEALTHCHECK instructions'
    __msg__ = 'Dockerfile does not contain any HEALTHCHECK instructions'
    __lifecycle_state__ = LifecycleStates.eol


class NoDockerfile(BaseTrigger):
    __trigger_name__ = 'nodockerfile'
    __description__ = 'triggers if anchore analysis was performed without supplying a real Dockerfile'
    __msg__ = 'Image was not analyzed with an actual Dockerfile'
    __lifecycle_state__ = LifecycleStates.eol


class DockerfileGate(Gate):
    __gate_name__ = 'dockerfilecheck'
    __description__ = 'Check Dockerfile Instructions'
    __lifecycle_state__ = LifecycleStates.eol
    __superceded_by__ = 'dockerfile'
    __triggers__ = [
        DirectiveCheckTrigger,
        EffectiveUserTrigger,
        ExposeTrigger,
        NoFromTrigger,
        FromScratch,
        NoTag,
        Sudo,
        VolumePresent,
        NoHealthCheck,
        NoDockerfile
    ]


class ContentMatchTrigger(BaseTrigger):
    __trigger_name__ = 'contentmatch'
    __description__ = 'Triggers if the content search analyzer has found any matches.  If the parameter is set, then will only trigger against found matches that are also in the FILECHECK_CONTENTMATCH parameter list.  If the parameter is absent or blank, then the trigger will fire if the analyzer found any matches.'
    __lifecycle_state__ = LifecycleStates.eol


class FilenameMatchTrigger(BaseTrigger):
    __trigger_name__ = 'filenamematch'
    __description__ = 'Triggers if a file exists in the container that matches with any of the regular expressions given as FILECHECK_NAMEREGEXP parameters.'
    __lifecycle_state__ = LifecycleStates.eol


class SuidCheckTrigger(BaseTrigger):
    __trigger_name__ = 'suidsgidcheck'
    __description__ = 'Fires for each file found to have suid or sgid set'
    __lifecycle_state__ = LifecycleStates.eol


class FileCheckGate(Gate):
    __gate_name__ = 'filecheck'
    __description__ = 'Image File Checks'
    __superceded_by__ = 'files'
    __lifecycle_state__ = LifecycleStates.eol
    __triggers__ = [
        ContentMatchTrigger,
        FilenameMatchTrigger,
        SuidCheckTrigger
    ]
