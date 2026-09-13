#!/usr/bin/env python3
"""Minimal DocBook refentry -> plain text, standing in for `xmlto txt`.

Only used to fill the --help / --manual heredocs of the xdg-utils
scripts; xmlto (and its lynx/links/w3m dependency chain) is not
installed on bero-os and is not worth pulling in for help text.
"""
import sys, re
import xml.etree.ElementTree as ET

def text(e):
    return re.sub(r'\s+', ' ', ''.join(e.itertext())).strip()

def wrap(s, indent=''):
    out, line = [], indent
    for w in s.split():
        if len(line) + len(w) + 1 > 76 and line.strip():
            out.append(line.rstrip()); line = indent
        line += w + ' '
    if line.strip():
        out.append(line.rstrip())
    return out

def main(path):
    root = ET.parse(path).getroot()
    L = []
    nd = root.find('refnamediv')
    L.append('Name')
    L.append('')
    name = text(nd.find('refname'))
    purpose = text(nd.find('refpurpose'))
    L += wrap('%s - %s' % (name, purpose), '       ')
    L.append('')
    syn = root.find('refsynopsisdiv')
    if syn is not None:
        L.append('Synopsis')
        L.append('')
        for cs in syn.findall('cmdsynopsis'):
            L += wrap(text(cs), '       ')
        L.append('')
    for sect in root.findall('refsect1'):
        t = sect.find('title')
        L.append(text(t) if t is not None else '')
        L.append('')
        for child in sect:
            if child.tag == 'title':
                continue
            if child.tag in ('variablelist', 'itemizedlist'):
                for item in child:
                    L += wrap(text(item), '       ')
                    L.append('')
            else:
                body = text(child)
                if body:
                    L += wrap(body, '       ')
                    L.append('')
        L.append('')
    sys.stdout.write('\n'.join(L) + '\n')

main(sys.argv[1])
