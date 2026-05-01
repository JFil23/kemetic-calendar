{{flutter_js}}
{{flutter_build_config}}

(function () {
  const buildVersion = {{flutter_service_worker_version}};
  const builds = window._flutter?.buildConfig?.builds;
  if (Array.isArray(builds) && buildVersion) {
    for (const build of builds) {
      if (typeof build.mainJsPath === 'string' && !build.mainJsPath.includes('?v=')) {
        build.mainJsPath = `${build.mainJsPath}?v=${buildVersion}`;
      }
      if (
        typeof build.jsSupportRuntimePath === 'string' &&
        !build.jsSupportRuntimePath.includes('?v=')
      ) {
        build.jsSupportRuntimePath = `${build.jsSupportRuntimePath}?v=${buildVersion}`;
      }
      if (typeof build.mainWasmPath === 'string' && !build.mainWasmPath.includes('?v=')) {
        build.mainWasmPath = `${build.mainWasmPath}?v=${buildVersion}`;
      }
    }
  }

  _flutter.loader.load();
})();
