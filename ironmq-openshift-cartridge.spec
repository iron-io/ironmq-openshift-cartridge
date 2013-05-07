%global cartridgedir %{_libexecdir}/openshift/cartridges/v2/ironmq
%global frameworkdir %{_libexecdir}/openshift/cartridges/v2/ironmq

Name: ironmq-openshift-cartridge
Version: 1.0.0
Release: 1%{?dist}
Summary: Embedded IronMQ support for OpenShift
Group: Development/Languages
License: ASL 2.0
URL: https://iron.io
Source0: http://TODO.com/FIXME
Requires:      rubygem(openshift-origin-node)
Requires:      openshift-origin-node-util

BuildArch:     noarch
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
BuildArch: noarch

%description
IronMQ cartridge for openshift. (Cartridge Format V2)


%prep
%setup -q

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}%{cartridgedir}
mkdir -p %{buildroot}/%{_sysconfdir}/openshift/cartridges/v2
cp -r * %{buildroot}%{cartridgedir}/
ln -s %{cartridgedir}/conf/ %{buildroot}/%{_sysconfdir}/openshift/cartridges/v2/%{name}

%clean
rm -rf %{buildroot}

%post
%{_sbindir}/oo-admin-cartridge --action install --offline --source /usr/libexec/openshift/cartridges/v2/ironmq

%files
%defattr(-,root,root,-)
%dir %{cartridgedir}
%dir %{cartridgedir}/bin
%dir %{cartridgedir}/env
%dir %{cartridgedir}/metadata
%dir %{cartridgedir}/versions
%attr(0755,-,-) %{cartridgedir}/bin/
%attr(0755,-,-) %{frameworkdir}
%{_sysconfdir}/openshift/cartridges/v2/%{name}
%{cartridgedir}/metadata/manifest.yml
%doc %{cartridgedir}/README.md
%doc %{cartridgedir}/LICENSE


%changelog
