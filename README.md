# openwrt-xray docker action

This action build xray with openwrt docker container.

## Inputs

### `compress-goproxy`

**Optional** Compiling with GOPROXY proxy. Default `"n"`.

### `exclude-assets`

**Optional** Exclude geoip.dat & geosite.dat. Default `"n"`.

### `compress-upx`

**Optional** Compress executable files with UPX. Default `"y"`.

### `compatibility-mode`

**Optional** V2ray Compatibility mode(v2ray soft connection Xray). Default `"n"`.

## Outputs

### `date`

The build date.

## Example usage

```bash
- name: Build aarch64_generic
  env:
    WORKSPACE: ${{ github.workspace }}
  uses: woniuzfb/openwrt-xray/.github/targets/aarch64_generic@v1
  with:
    compress-goproxy: 'n'
    exclude-assets: 'n'
    compress-upx: 'y'
    compatibility-mode: 'n'
- name: Build aarch64_cortex-a53
  env:
    WORKSPACE: ${{ github.workspace }}
  uses: woniuzfb/openwrt-xray/.github/targets/aarch64_cortex-a53@v1
  with:
    compress-goproxy: 'n'
    exclude-assets: 'n'
    compress-upx: 'y'
    compatibility-mode: 'n'

git tag -a v1.x.x
git push origin v1.x.x
```
