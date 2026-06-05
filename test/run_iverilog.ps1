$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$BuildDir = Join-Path $RepoRoot "build"
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

function Run-Test {
    param(
        [string] $Name,
        [string[]] $Sources
    )

    $OutFile = Join-Path $BuildDir "$Name.vvp"
    Write-Host "==> Building $Name"
    & iverilog -g2012 -I"$RepoRoot/src" -o $OutFile @Sources
    if ($LASTEXITCODE -ne 0) { throw "iverilog failed for $Name" }

    Write-Host "==> Running $Name"
    & vvp $OutFile
    if ($LASTEXITCODE -ne 0) { throw "vvp failed for $Name" }
}

Run-Test "tb_step_control_multi" @(
    "$RepoRoot/test/tb_step_control_multi.sv",
    "$RepoRoot/src/step_control_multi.sv"
)

Run-Test "tb_voxel_raytracer_core_tags" @(
    "$RepoRoot/test/tb_voxel_raytracer_core_tags.sv",
    "$RepoRoot/src/axis_choose.sv",
    "$RepoRoot/src/bounds_check.sv",
    "$RepoRoot/src/step_update.sv",
    "$RepoRoot/src/voxel_addr_map.sv",
    "$RepoRoot/src/voxel_ram.sv",
    "$RepoRoot/src/scene_loader_if.sv",
    "$RepoRoot/src/voxel_raytracer_core.sv"
)

Run-Test "tb_raytracer_top_multi" @(
    "$RepoRoot/test/tb_raytracer_top_multi.sv",
    "$RepoRoot/src/axis_choose.sv",
    "$RepoRoot/src/bounds_check.sv",
    "$RepoRoot/src/step_update.sv",
    "$RepoRoot/src/voxel_addr_map.sv",
    "$RepoRoot/src/voxel_ram.sv",
    "$RepoRoot/src/scene_loader_if.sv",
    "$RepoRoot/src/voxel_raytracer_core.sv",
    "$RepoRoot/src/step_control_multi.sv",
    "$RepoRoot/src/raytracer_top.sv"
)

Write-Host "All Icarus tests passed."
