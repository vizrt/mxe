#!/usr/bin/python3

"""
    This script reads the pasta package definition files in pasta_defintions/*
    and resolves all DLL depenencies and create Package.info, winconfig and
    bundle wscript for each package. It will also put dependencies between
    the PaSta packages. For instance ffmpeg will depend on the SDL package
    because of ffplay etc.

    Dependencies that are common between 2 or more packages will be put into
    the MXE.Common package.
"""

import os
import sys
import re
import json
import shutil
import glob
from subprocess import Popen, PIPE

sys.path.append("CPP.Package.Utilities")
from cpp_package.winconfig import create_winconfig, create_winconfig_alias
from cpp_package.vizwaf import create_vizwaf

OBJDUMP="usr/bin/x86_64-w64-mingw32.shared-objdump"
ROOT="usr/x86_64-w64-mingw32.shared"
ROOTBIN=os.path.join(ROOT, "bin")
ROOTINCLUDE=os.path.join(ROOT, "include")
OUTPUT="bundle"

not_found = set()

def find_dll_dependencies(dll, result):
    filename = os.path.join(ROOTBIN, dll)

    if not os.path.exists(filename):
        if dll not in not_found:
            sys.stderr.write("WARNING: Could not find {}\n".format(dll))
            not_found.update([dll])
        return

    result.update([dll])

    p = Popen([OBJDUMP, "-x", filename], stdout=PIPE, stderr=PIPE)
    stdout, _ = p.communicate()

    deps = []

    for line in stdout.decode("utf-8").splitlines():
        m = re.search("\s*DLL Name:\s*(\S+)\s*", line)
        if m:
            deps.append(m.group(1))

    for dep in deps:
        if dep in result: continue

        find_dll_dependencies(dep, result)

def find_imp_lib_dll(implib):
    filename = os.path.join(ROOTBIN, implib)

    if not os.path.exists(filename):
        raise Exception("Could not find implib: {}".format(filename))

    p = Popen([OBJDUMP, "-xs", filename], stdout=PIPE, stderr=PIPE)
    stdout, _ = p.communicate()

    if p.returncode != 0:
        raise Exception("Failed to parse implib: {}".format(filename))

    for line in stdout.decode("utf-8").splitlines():
        m = re.search("\s*(\S+\.dll)\.*", line)
        if m:
            return m.group(1)

    raise Exception("Could not find DLL reference in implib: {}".format(filename))


if __name__ == "__main__":
    packages = {}

    provides = {}
    for package_definition in glob.glob("pasta_definitions/*.def"):
        print("Parsing package definition: {}".format(package_definition))

        with open(package_definition, "rb") as f:
            definition = json.loads(f.read())

        name = definition["name"]

        result = set()
        for implib in definition["lib"]:
            dll = find_imp_lib_dll(implib)
            provides[dll] = name

            find_dll_dependencies(dll, result)


        packages[name] = definition
        packages[name]["dll"] = result
        packages[name]["deps"] = ["mxe"]

    all_dlls = set()
    common_dlls = set()

    for name, package in packages.items():
        for dll in package["dll"]:
            if dll in provides and name != provides[dll]:
                package["deps"].append(provides[dll])
                continue

            if dll in all_dlls:
                common_dlls.update([dll])
            else:
                all_dlls.update([dll])

    for name, package in packages.items():
        package["dll"] = list(package["dll"].difference(common_dlls))

        for dll, provided_by in provides.items():
            if name != provided_by and dll in package["dll"]:
                package["dll"].remove(dll)

    packages["mxe"] = {
        "package_name" : "MXE.Common",
        "dll" : list(common_dlls),
        "lib" : [],
        "deps" : [],
        "version" : "0.0.0"
    }

    pkg_pattern = '{}.windows.x64'
    for name, package in packages.items():
        package["package_name"] = pkg_pattern.format(package["package_name"])

    if os.path.exists(OUTPUT):
        shutil.rmtree(OUTPUT)

    os.mkdir(OUTPUT)

    with open("pasta_templates/Package.template", "rb") as f:
        package_info_template = f.read().decode("utf-8")

    for name, package in packages.items():
        print("Copying files for package: {}".format(name))

        package_version = package["version"]
        package_name = package["package_name"]

        dependency_lines = ""
        winconfig_requires = ""
        for dep in package["deps"]:
            version = packages[dep]["version"]
            pkg_name = packages[dep]["package_name"]
            dependency_lines += "Depends: {} ({})\n".format(pkg_name, version)
            winconfig_requires += "    ctx.requires('{}')\n".format(dep)

        prefix = os.path.join(OUTPUT, name)
        bindir = os.path.join(prefix, "bin")
        libdir = os.path.join(prefix, "lib")
        includedir = os.path.join(prefix, "include")
        winconfigdir = os.path.join(libdir, "winconfig")

        os.mkdir(prefix)
        os.mkdir(bindir)
        os.mkdir(libdir)
        os.mkdir(includedir)
        os.mkdir(winconfigdir)

        for dll in package["dll"] + package.get("exe", []):
            src = os.path.join(ROOTBIN, dll)
            dst = os.path.join(bindir, dll)
            shutil.copy(src, dst)

        for dll in package["lib"]:
            src = os.path.join(ROOTBIN, dll)
            dst = os.path.join(libdir, dll)
            shutil.copy(src, dst)

        for include in package.get("include", []):
            full_include = os.path.join(ROOTINCLUDE, include)

            if os.path.isdir(full_include):
                shutil.copytree(full_include, os.path.join(includedir, include))
            else:
                shutil.copy(full_include, os.path.join(includedir, include))

        for src, dst in package.get("extra", {}).items():
            shutil.copy(src, os.path.join(prefix, dst))

        subst_values = {
            "NAME" : name,
            "PACKAGE_NAME" : package_name,
            "VERSION" : package_version,
            "DEPENDS" : dependency_lines,
            "WINCONFIG_REQUIRES" : winconfig_requires,
            "LIBS" : str(package["lib"]),
            "DLLS" : str(package["dll"]),
            "DEPS" : str(package["deps"])
        }

        package_info_filename = os.path.join(prefix, "Package.info")
        with open(package_info_filename, "wb") as f:
            f.write(package_info_template.format(**subst_values).encode("utf-8"))

        include_paths = package.get("include_paths", ["include"])

        create_vizwaf(name, prefix, include_paths)

        create_winconfig(name, prefix, include_paths, deps=package["deps"])

        for alias in package.get("openbuild_aliases", []):
            create_winconfig_alias(alias, prefix, name)

