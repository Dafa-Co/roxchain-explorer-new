import { Flex, Text } from '@chakra-ui/react';
import React from 'react';

import type { Transaction } from 'types/api/transaction';

import useApiQuery from 'lib/api/useApiQuery';
import NftEntity from 'ui/shared/entities/nft/NftEntity';
import NativeCoinValue from 'ui/shared/value/NativeCoinValue';
import TokenValue from 'ui/shared/value/TokenValue';

interface Props {
  readonly tx: Transaction;
  readonly isLoading?: boolean;
}

const ACCURACY = 5;
const NFT_COLLECTION_MAX_W = '120px';

// RoxChain: a token transfer sends 0 ROX, so "Value 0 ROX" says nothing; show the amount of the token it moved instead.
// Token transfers are not part of the transaction list response, so they are fetched only for those rows.
const LatestTxsValue = ({ tx, isLoading }: Props) => {
  const isTokenTransfer = tx.value === '0' && Boolean(tx.transaction_types?.includes('token_transfer'));

  const tokenTransfersQuery = useApiQuery('general:tx_token_transfers', {
    pathParams: { hash: tx.hash },
    queryOptions: { enabled: isTokenTransfer && !isLoading, staleTime: Infinity },
  });

  const transfer = tokenTransfersQuery.data?.items[0];
  const total = transfer?.total;

  // fungible tokens (ERC-20, also ERC-1155 / ERC-404 amounts): "10 USDT"
  if (isTokenTransfer && transfer?.token && total && 'value' in total && total.value) {
    return (
      <TokenValue
        amount={ total.value }
        token={ transfer.token }
        decimals={ total.decimals ?? transfer.token.decimals }
        accuracy={ ACCURACY }
        loading={ isLoading }
        color="text.secondary"
      />
    );
  }

  // NFTs (ERC-721): no amount, show the collection and the token id on one line, "collection #1"
  if (isTokenTransfer && transfer?.token && total && 'token_id' in total && total.token_id) {
    const collection = transfer.token.symbol || transfer.token.name || '';
    return (
      <Flex as="span" display="inline-flex" alignItems="center" flexWrap="nowrap" maxW="100%" color="text.secondary">
        <Text as="span" color="text.secondary" whiteSpace="nowrap" overflow="hidden" textOverflow="ellipsis" maxW={ NFT_COLLECTION_MAX_W } title={ collection }>
          { collection }
        </Text>
        <Text as="span" color="text.secondary" ml={ 1 }>#</Text>
        <NftEntity
          hash={ transfer.token.address_hash }
          id={ total.token_id }
          instance={ total.token_instance }
          isLoading={ isLoading }
          noIcon
          noCopy
        />
      </Flex>
    );
  }

  return (
    <NativeCoinValue
      amount={ tx.value }
      accuracy={ ACCURACY }
      loading={ isLoading || (isTokenTransfer && tokenTransfersQuery.isLoading) }
      color="text.secondary"
    />
  );
};

export default React.memo(LatestTxsValue);
