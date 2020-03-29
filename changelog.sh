#!/bin/bash
StatusFile=status.env
NewStatusFile=newstatus.env
URLFile=name_and_urls.env
ChangeLogFile=CHANGELOG.md
BuildTag="R2S-Lean-$(date +%Y-%m-%d)-$BuilderHash"
env | grep "Hash" > $NewStatusFile
ChangeLog=""
while read l; do
    IFS='='
    read -ra Parts <<< "$l"
    name=${Parts[0]/Hash/}
    hash=${Parts[1]}
    hash=$(echo $hash | cut -c -7)
    url=""
    if [ -f "$URLFile" ]; then
        urlLine=$(grep $URLFile -e ${name}URL)
        url=$(echo "${urlLine/${name}URL=/}")
    fi

    oldLine=""
    if [ -f "$StatusFile" ]; then
        oldLine=$(grep $StatusFile -e ${name}Hash)
    fi
    title=""
    body=""
    if [ "$oldLine" == "" ]; then
        title="${name} [$hash]($url/commit/$hash)"
    else
        read -ra Parts <<< "$oldLine"
        oldHash=${Parts[1]}
        oldHash=$(echo $oldHash | cut -c -7)
        if ! [ "$oldHash" == "$hash" ]; then
            title="${name} [${oldHash}..$hash]($url/compare/$oldHash..$hash)"
            mkdir -p .temprepo
            cd .temprepo
            git init
            git remote add $name ${url}.git
            git fetch $name
            body="
| Commit | Author | Desc |
| :----- | :------| :--- |
"
            echo "Generating Change Log for $name ${oldHash}..${hash}"
            table=$(git log --no-merges --invert-grep --author="action@github.com" --pretty=format:'| %h | %an | %s |' ${oldHash}..${hash} ${name}/master)
            if [ "$table" == "" ]; then
                body=""
            else
                body="$body$table"
            fi
            cd ..
        fi
    fi
    if ! [ "$title" == "" ]; then
    ChangeLog="${ChangeLog}#### $title

$body


"
    fi
done <$NewStatusFile

echo "$ChangeLog"

ChangeLogEscaped="${ChangeLog//'%'/'%25'}"
ChangeLogEscaped="${ChangeLogEscaped//$'\n'/'%0A'}"
ChangeLogEscaped="${ChangeLogEscaped//$'\r'/'%0D'}" 
echo "::set-output name=changelog::$ChangeLogEscaped" 
echo "::set-output name=buildtag::$BuildTag"
if [ "$ChangeLog" == "" ]; then
    echo "No Change Happened, We Should Not Build."
    exit 0
fi

ChangeLogFull="## $BuildTag

$ChangeLog

--------------
"
touch $ChangeLogFile
printf '%s\n%s\n' "$ChangeLogFull" "$(cat $ChangeLogFile)" >$ChangeLogFile
rm $StatusFile
mv $NewStatusFile $StatusFile
git add $StatusFile
git add $ChangeLogFile
git commit -m "ChangeLog for $BuildTag"
# git push
