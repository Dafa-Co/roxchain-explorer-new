import React from 'react';

import type { Address } from 'types/api/address';

import { NFT_TOKEN_TYPE_IDS } from 'lib/token/tokenTypes';
import { Skeleton } from 'toolkit/chakra/skeleton';
import * as DetailedInfo from 'ui/shared/DetailedInfo/DetailedInfo';
import TokenEntity from 'ui/shared/entities/token/TokenEntity';

interface Props {
  data: Pick<Address, 'name' | 'token' | 'is_contract'>;
  isLoading?: boolean;
}

const AddressNameInfo = ({ data, isLoading }: Props) => {
  if (data.token) {
    // RoxChain: NFT contracts (ERC-721 / ERC-1155 / ERC-404) are collections of NFTs
    const isNft = NFT_TOKEN_TYPE_IDS.some((type) => type === data.token?.type);
    return (
      <>
        <DetailedInfo.ItemLabel
          hint={ isNft ? 'NFT collection name and symbol' : 'Token name and symbol' }
          isLoading={ isLoading }
        >
          { isNft ? 'NFT collection' : 'Token name' }
        </DetailedInfo.ItemLabel>
        <DetailedInfo.ItemValue>
          <TokenEntity
            token={ data.token }
            isLoading={ isLoading }
            noIcon
            noCopy
          />
        </DetailedInfo.ItemValue>
      </>
    );
  }

  if (data.is_contract && data.name) {
    return (
      <>
        <DetailedInfo.ItemLabel
          hint="The name found in the source code of the Contract"
          isLoading={ isLoading }
        >
          Contract name
        </DetailedInfo.ItemLabel>
        <DetailedInfo.ItemValue>
          <Skeleton loading={ isLoading }>
            { data.name }
          </Skeleton>
        </DetailedInfo.ItemValue>
      </>
    );
  }

  if (data.name) {
    return (
      <>
        <DetailedInfo.ItemLabel
          hint="The name of the validator"
          isLoading={ isLoading }
        >
          Validator name
        </DetailedInfo.ItemLabel>
        <DetailedInfo.ItemValue>
          <Skeleton loading={ isLoading }>
            { data.name }
          </Skeleton>
        </DetailedInfo.ItemValue>
      </>
    );
  }

  return null;
};

export default React.memo(AddressNameInfo);
