import type { GetServerSidePropsContext, GetServerSidePropsResult } from 'next';

import type { Route } from 'nextjs-routes';

import config from 'configs/app';
import * as cookies from 'lib/cookies';
import type * as metadata from 'lib/metadata';

export interface Props<Pathname extends Route['pathname'] = never> {
  query: Route['query'];
  cookies: string;
  referrer: string;
  // if apiData is undefined, Next.js will complain that it is not serializable
  // so we force it to be always present in the props but it can be null
  apiData: metadata.ApiData<Pathname> | null;
  uuid: string;
}

export const base = async <Pathname extends Route['pathname'] = never>({ req, res, query }: GetServerSidePropsContext):
Promise<GetServerSidePropsResult<Props<Pathname>>> => {
  const appProfile = req.headers?.['x-app-profile'] || cookies.getFromCookieString(req.headers.cookie || '', cookies.NAMES.APP_PROFILE);
  let uuid = cookies.getFromCookieString(req.headers.cookie || '', cookies.NAMES.UUID);
  if (!uuid && appProfile !== 'private') {
    uuid = crypto.randomUUID();
    res.setHeader('Set-Cookie', `${ cookies.NAMES.UUID }=${ uuid }; Path=/${ config.app.protocol === 'https' ? '; Secure' : '' }`);
  }

  return {
    props: {
      query,
      cookies: req.headers.cookie || '',
      referrer: req.headers.referer || '',
      apiData: null,
      uuid,
    },
  };
};
