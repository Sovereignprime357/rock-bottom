# Compact Tony evidence packager

Explicit successor to the unexecuted 96 MB plan. Root executes these commands:

```powershell
python -B .build/3d/tony-coat-evidence-compact-draft/package.py plan
python -B .build/3d/tony-coat-evidence-compact-draft/package.py seal --write --disposition .build/full-port/tony-coat-surfaces-visual/VISUAL-ACCEPTANCE.md
python -B .build/3d/tony-coat-evidence-compact-draft/package.py verify
python -B .build/3d/tony-coat-evidence-compact-draft/package.py copy --write
```

Fixed fresh destination: `artifacts/3d-full-port/resident-polish/tony-coats`.
Only 24 original PNGs are portable: 17 accepted native, five root-inspected
accepted Web and two earlier native defect images. `RAW-LOCATORS.json` pins
all 299 raw evidence inputs. Full Web bundles and other images remain local.
`DERIVED-WEB-STATUS.json` is explicitly derived and omits base64 frame payloads.
The script still audits all 68 local original images before sealing/copying.

Core actual failures/successes, exact source/spec/test lineage, final UID and
root's verbatim disposition are retained. Archives/exports/projects are not
duplicated. Final package size, including its receipt, must be <=22,000,000
bytes. Hash drift, existing outputs and unsafe paths are refused. No engine,
browser, Git, source promotion or automatic visual/full-port verdict occurs.
