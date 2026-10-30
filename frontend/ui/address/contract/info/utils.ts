import { stripLeadingSlash } from 'toolkit/utils/url';

export function getGitHubOwnerAndRepo(repositoryUrl: string) {
  try {
    const urlObj = new URL(repositoryUrl);
    if (urlObj.hostname !== 'github.com') {
      throw new Error();
    }
    const [ owner, repo, ...rest ] = stripLeadingSlash(urlObj.pathname).split('/');
    return { owner, repo, rest, url: urlObj };
  } catch (error) {
    return;
  }
}
