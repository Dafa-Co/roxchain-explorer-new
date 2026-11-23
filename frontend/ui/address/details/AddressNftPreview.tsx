import { Box, Flex, Text } from '@chakra-ui/react';
import React from 'react';

import type { TokenInfo, TokenInstance } from 'types/api/token';

import { route } from 'nextjs/routes';

import useApiQuery from 'lib/api/useApiQuery';
import { NFT_TOKEN_TYPE_IDS } from 'lib/token/tokenTypes';
import { Link } from 'toolkit/chakra/link';
import { Skeleton } from 'toolkit/chakra/skeleton';
import * as DetailedInfo from 'ui/shared/DetailedInfo/DetailedInfo';
import NftMedia from 'ui/shared/nft/NftMedia';

interface Props {
  readonly token: TokenInfo;
  readonly isLoading?: boolean;
}

const PREVIEW_COUNT = 6;
const CARD_W = '128px';

// RoxChain: the name of an NFT from its metadata ("name", or a "name" attribute as RoxCustody writes it)
function getNftName(item: TokenInstance): string | undefined {
  const metadata = item.metadata;
  if (!metadata) {
    return undefined;
  }
  if (typeof metadata.name === 'string' && metadata.name) {
    return metadata.name;
  }
  const attributes = Array.isArray(metadata.attributes) ? metadata.attributes as Array<{ trait_type?: unknown; value?: unknown }> : [];
  const nameAttribute = attributes.find((attribute) => attribute?.trait_type === 'name');
  return typeof nameAttribute?.value === 'string' ? nameAttribute.value : undefined;
}

// RoxChain: on the page of an NFT collection contract, show its first NFTs (image, id, name), linked to each NFT and to the collection
const AddressNftPreview = ({ token, isLoading }: Props) => {
  const isNft = NFT_TOKEN_TYPE_IDS.some((type) => type === token.type);

  const inventoryQuery = useApiQuery('general:token_inventory', {
    pathParams: { hash: token.address_hash },
    queryOptions: { enabled: isNft && !isLoading },
  });

  const items = React.useMemo(() => inventoryQuery.data?.items.slice(0, PREVIEW_COUNT) ?? [], [ inventoryQuery.data ]);

  if (!isNft || (!inventoryQuery.isLoading && items.length === 0)) {
    return null;
  }

  const collectionUrl = route({ pathname: '/token/[hash]', query: { hash: token.address_hash, tab: 'inventory' } });

  return (
    <>
      <DetailedInfo.ItemLabel
        hint="NFTs of this collection: image, ID and name"
        isLoading={ isLoading || inventoryQuery.isLoading }
      >
        NFTs
      </DetailedInfo.ItemLabel>
      <DetailedInfo.ItemValue multiRow>
        <Flex flexWrap="wrap" gap={ 3 } w="100%">
          { items.map((item) => {
            const itemUrl = route({ pathname: '/token/[hash]/instance/[id]', query: { hash: token.address_hash, id: item.id } });
            const name = getNftName(item);
            return (
              <Box
                key={ item.id }
                w={ CARD_W }
                border="1px solid"
                borderColor="border.divider"
                borderRadius="md"
                p={ 2 }
                textStyle="sm"
              >
                <Link href={ itemUrl } display="block" mb={ 2 }>
                  <NftMedia data={ item } size="sm" autoplayVideo={ false } isLoading={ inventoryQuery.isLoading }/>
                </Link>
                <Skeleton loading={ inventoryQuery.isLoading }>
                  <Link href={ itemUrl } fontWeight={ 600 }>#{ item.id }</Link>
                  { name && (
                    <Text color="text.secondary" overflow="hidden" textOverflow="ellipsis" whiteSpace="nowrap" title={ name }>
                      { name }
                    </Text>
                  ) }
                </Skeleton>
              </Box>
            );
          }) }
        </Flex>
        <Link href={ collectionUrl } mt={ 2 } display="inline-block" loading={ inventoryQuery.isLoading }>
          View the collection and all its NFTs
        </Link>
      </DetailedInfo.ItemValue>
    </>
  );
};

export default React.memo(AddressNftPreview);
